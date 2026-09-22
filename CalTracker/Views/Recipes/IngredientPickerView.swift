import SwiftUI

/// Adds an ingredient to a recipe, either typed by hand or imported from
/// Open Food Facts (which also brings its macros along).
struct IngredientPickerView: View {
    let onAdd: (IngredientDraft) -> Void

    private enum Mode: String, CaseIterable, Identifiable {
        case manual
        case database

        var id: String { rawValue }

        var title: String {
            switch self {
            case .manual: return "Manuel"
            case .database: return "Open Food Facts"
            }
        }
    }

    @Environment(\.foodDatabaseClient) private var client
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .manual
    @State private var viewModel: FoodSearchViewModel?
    @State private var pendingFood: RemoteFood?

    // Manual entry fields.
    @State private var name = ""
    @State private var quantityText = ""
    @State private var unit: MeasurementUnit = .gram
    @State private var isPantryStaple = false

    private var quantity: Double {
        Double.parseUserInput(quantityText) ?? 0
    }

    private var canAddManually: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && quantity > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch mode {
            case .manual:
                manualForm
            case .database:
                databaseSearch
            }
        }
        .navigationTitle("Ingrédient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            if mode == .manual {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter", action: addManualIngredient)
                        .disabled(!canAddManually)
                }
            }
        }
        .sheet(item: $pendingFood) { food in
            NavigationStack {
                IngredientQuantitySheet(food: food) { draft in
                    onAdd(draft)
                    dismiss()
                }
            }
            .presentationDetents([.medium])
        }
        .task {
            if viewModel == nil {
                viewModel = FoodSearchViewModel(client: client)
            }
        }
    }

    private var manualForm: some View {
        Form {
            Section {
                TextField("Nom de l'ingrédient", text: $name)
                HStack {
                    TextField("Quantité", text: $quantityText)
                        .keyboardType(.decimalPad)
                    Picker("Unité", selection: $unit) {
                        ForEach(MeasurementUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .labelsHidden()
                }
                Toggle("Produit de placard", isOn: $isPantryStaple)
            } footer: {
                Text("Les produits de placard (huile, sel, épices) peuvent être exclus de la liste de courses.")
            }
        }
    }

    @ViewBuilder
    private var databaseSearch: some View {
        if let viewModel {
            Group {
                switch viewModel.state {
                case .idle:
                    ContentUnavailableView(
                        "Rechercher un produit",
                        systemImage: "magnifyingglass",
                        description: Text("Les macros du produit seront reprises dans la recette.")
                    )
                case .searching:
                    ProgressView("Recherche…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .results(let foods):
                    List(foods) { food in
                        Button {
                            pendingFood = food
                        } label: {
                            RemoteFoodRow(food: food)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
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
            .searchable(
                text: Binding(get: { viewModel.query }, set: { viewModel.updateQuery($0) }),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Rechercher un produit"
            )
        } else {
            Color.clear
        }
    }

    private func addManualIngredient() {
        onAdd(
            IngredientDraft(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                unit: unit,
                isPantryStaple: isPantryStaple
            )
        )
        dismiss()
    }
}

/// Asks for the quantity of an imported product before adding it to a recipe.
private struct IngredientQuantitySheet: View {
    let food: RemoteFood
    let onAdd: (IngredientDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quantityText = "100"
    @State private var unit: MeasurementUnit = .gram

    private var quantity: Double {
        Double.parseUserInput(quantityText) ?? 0
    }

    private var preview: NutritionFacts {
        guard unit.dimension != .count else { return .zero }
        return NutritionCalculator.nutrition(
            for: food.nutritionPer100g,
            quantityInGrams: quantity * unit.baseUnitFactor
        )
    }

    var body: some View {
        Form {
            Section {
                Text(food.displayName)
                    .font(.headline)
            }

            Section("Quantité dans la recette") {
                HStack {
                    TextField("100", text: $quantityText)
                        .keyboardType(.decimalPad)
                    Picker("Unité", selection: $unit) {
                        ForEach(MeasurementUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .labelsHidden()
                }
            }

            Section("Apports") {
                NutritionBreakdownView(facts: preview)
            }
        }
        .navigationTitle("Ajouter l'ingrédient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") {
                    onAdd(
                        IngredientDraft(
                            name: food.name,
                            quantity: quantity,
                            unit: unit,
                            barcode: food.barcode,
                            nutritionPer100g: food.nutritionPer100g
                        )
                    )
                    dismiss()
                }
                .disabled(quantity <= 0)
            }
        }
    }
}
