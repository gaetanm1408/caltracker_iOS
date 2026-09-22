import AVFoundation
import SwiftUI
import UIKit
import Vision
import VisionKit

/// Camera sheet that reads a food barcode and hands the payload back.
///
/// Handles the three states the camera can be in before scanning is possible:
/// hardware support, permission still to be asked, permission refused.
struct BarcodeScannerSheet: View {
    let onScan: (String) -> Void

    private enum Status {
        case checking
        case unsupported
        case denied
        case scanning
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var status: Status = .checking

    var body: some View {
        Group {
            switch status {
            case .checking:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .unsupported:
                ContentUnavailableView(
                    "Scanner indisponible",
                    systemImage: "camera.fill",
                    description: Text("Cet appareil ne permet pas de scanner un code-barres. Utilise la recherche par nom.")
                )
            case .denied:
                ContentUnavailableView {
                    Label("Accès à la caméra refusé", systemImage: "camera.badge.ellipsis")
                } description: {
                    Text("Autorise l'accès à la caméra dans les réglages pour scanner un produit.")
                } actions: {
                    Button("Ouvrir les réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .scanning:
                BarcodeScannerRepresentable(onScan: onScan)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) {
                        Text("Vise le code-barres du produit")
                            .font(.footnote)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 32)
                    }
            }
        }
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
        }
        .task { await resolveStatus() }
    }

    private func resolveStatus() async {
        guard DataScannerViewController.isSupported else {
            status = .unsupported
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            status = .scanning
        case .notDetermined:
            status = await AVCaptureDevice.requestAccess(for: .video) ? .scanning : .denied
        default:
            status = .denied
        }
    }
}

/// Wraps VisionKit's scanner, restricted to the symbologies food products use.
private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        // Scanning can only start once the controller is on screen, and a
        // second call would throw, so it is attempted exactly once.
        guard !context.coordinator.didStart else { return }
        context.coordinator.didStart = true
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        var didStart = false
        private var hasReported = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // The camera keeps recognising the same barcode frame after frame;
            // only the first reading is forwarded.
            guard !hasReported else { return }

            for case .barcode(let barcode) in addedItems {
                guard let payload = barcode.payloadStringValue, !payload.isEmpty else { continue }
                hasReported = true
                dataScanner.stopScanning()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onScan(payload)
                return
            }
        }
    }
}
