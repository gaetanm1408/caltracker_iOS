import SwiftUI

/// Thème choisi par l'utilisateur, ou celui du système.
///
/// Stocké hors de SwiftData : c'est une préférence d'affichage, pas une donnée,
/// et elle doit être lisible avant même que le conteneur soit ouvert.
enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    static let storageKey = "appearancePreference"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .system: return "Système"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }

    var systemImageName: String {
        switch self {
        case .system: return "iphone"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// `nil` laisse la main au réglage de l'iPhone.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
