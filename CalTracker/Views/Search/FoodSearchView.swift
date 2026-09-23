import SwiftData
import SwiftUI

/// Searches Open Food Facts and lets the user log a result into the journal.
struct FoodSearchView: View {
    var targetDate: Date = .now
    var isEmbeddedInSheet: Bool = false

    @Environment(\.foodDatabaseClient) private var client
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: FoodSearchViewModel?
    @State private var selectedFood: RemoteFood?
    @State private var isPresentingScanner = false
    @State private var scannedBarcode: String?
    @State private var productForList: RemoteFood?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
                    .searchable(
                        text: Binding(
                            get: { viewModel.query },
                            set: { viewModel.updateQuery($0) }
                        ),
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Rechercher un produit"
                    )
                    .onSubmit(of: .search) { viewModel.searchNow() }
            } else {
                Color.clear
            }
        }
        .navigationTitle("Recherche")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEmbeddedInSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingScanner = true
                } label: {
                    Label("Scanner un code-barres", systemImage: "barcode.viewfinder")
                }
            }
        }
        .sheet(isPresented: $isPresentingScanner, onDismiss: lookupScannedBarcode) {
            NavigationStack {
                BarcodeScannerSheet { barcode in
                    scannedBarcode = barcode
                    isPresentingScanner = false
                }
            }
        }
        .sheet(item: $selectedFood) { food in
            NavigationStack {
                AddFoodSheet(food: food, targetDate: targetDate) {
                    if isEmbeddedInSheet { dismiss() }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            if viewModel == nil {
                viewModel = FoodSearchViewModel(client: client)
            }
        }
    }

    /// Runs once the scanner sheet is gone, so the logging sheet is presented
    /// on a free presentation slot rather than over a dismissing one.
    private func lookupScannedBarcode() {
        guard let barcode = scannedBarcode, let viewModel else { return }
        scannedBarcode = nil
        Task {
            selectedFood = await viewModel.lookup(barcode: barcode)
        }
    }

    @ViewBuilder
    private func content(for viewModel: FoodSearchViewModel) -> some View {
        switch viewModel.state {
        case .idle:
            RecentProductsList(targetDate: targetDate, onDismiss: {
                if isEmbeddedInSheet { dismiss() }
            })
        case .searching:
            ProgressView("Recherche en cours…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .results:
            VStack(spacing: 0) {
                if !viewModel.availableCategories.isEmpty {
                    CategoryFilterBar(
                        categories: viewModel.availableCategories,
                        selected: viewModel.selectedCategory,
                        onSelect: { viewModel.toggleCategory($0) }
                    )
                }

                if viewModel.visibleResults.isEmpty {
                    ContentUnavailableView(
                        "Aucun produit dans cette catégorie",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Touche à nouveau la catégorie pour retirer le filtre.")
                    )
                } else {
                    List(viewModel.visibleResults) { food in
                        // Une ligne simple plutôt qu'un bouton : un Button en
                        // style « plain » capte les gestes horizontaux et prive
                        // la liste de son balayage.
                        RemoteFoodRow(food: food)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedFood = food }
                            .swipeActions(edge: .leading) {
                                Button {
                                    productForList = food
                                } label: {
                                    Label("Courses ou recette", systemImage: "cart.badge.plus")
                                }
                                .tint(.green)
                            }
                            .contextMenu {
                                Button {
                                    productForList = food
                                } label: {
                                    Label("Ajouter aux courses ou à une recette", systemImage: "cart.badge.plus")
                                }
                            }
                    }
                    .listStyle(.plain)
                    .sheet(item: $productForList) { food in
                        NavigationStack {
                            AddProductToListSheet(food: food)
                        }
                        .presentationDetents([.medium, .large])
                    }
                }
            }
        case .empty(let query):
            ContentUnavailableView.search(text: query)
        case .failed(let message):
            ContentUnavailableView {
                Label("Recherche impossible", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Réessayer") { viewModel.searchNow() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Bandeau de catégories issu des résultats affichés : les libellés viennent
/// d'Open Food Facts, déjà traduits.
private struct CategoryFilterBar: View {
    let categories: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = category == selected
                    Button {
                        onSelect(category)
                    } label: {
                        Text(category)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    isSelected ? Color.accentColor : Color.secondary.opacity(0.15)
                                )
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

/// Shown before a search starts: products already logged, to re-add in one tap.
private struct RecentProductsList: View {
    let targetDate: Date
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<FoodProduct> { $0.lastUsedAt != nil },
        sort: [SortDescriptor(\FoodProduct.lastUsedAt, order: .reverse)]
    )
    private var recents: [FoodProduct]

    @State private var selectedProduct: FoodProduct?

    var body: some View {
        if recents.isEmpty {
            ContentUnavailableView(
                "Recherche un aliment",
                systemImage: "magnifyingglass",
                description: Text("Tape le nom d'un produit pour interroger la base Open Food Facts.")
            )
        } else {
            List {
                Section("Récemment utilisés") {
                    ForEach(recents.prefix(15)) { product in
                        Button {
                            selectedProduct = product
                        } label: {
                            StoredProductRow(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .sheet(item: $selectedProduct) { product in
                NavigationStack {
                    AddFoodSheet(product: product, targetDate: targetDate, onLogged: onDismiss)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

#Preview {
    NavigationStack {
        FoodSearchView()
    }
    .modelContainer(PreviewData.container())
    .environment(\.foodDatabaseClient, StubFoodDatabaseClient())
}
