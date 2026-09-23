import SwiftData
import SwiftUI

/// Envoie un produit trouvé dans la recherche vers la liste de courses ou vers
/// une recette, sans passer par le journal.
struct AddProductToListSheet: View {
    let food: RemoteFood

    private enum Destination: String, CaseIterable, Identifiable {
        case shoppingList
        case recipe

        var id: String { rawValue }

        var title: String {
            switch self {
            case .shoppingList: return "Liste de courses"
            case .recipe: return "Recette"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Recipe.name)]) private var recipes: [Recipe]

    @State private var destination: Destination = .shoppingList
    @State private var quantityText = "1"
    @State private var unit: MeasurementUnit = .piece
    @State private var selectedRecipeID: UUID?
    @State private var newRecipeName = ""
    @State private var errorMessage: String?

    private var quantity: Double {
        Double.parseUserInput(quantityText) ?? 0
    }

    private var isCreatingRecipe: Bool {
        selectedRecipeID == nil
    }

    private var selectedRecipe: Recipe? {
        recipes.first { $0.id == selectedRecipeID }
    }

    private var canSave: Bool {
        guard quantity > 0 else { return false }
        guard destination == .recipe else { return true }
        return selectedRecipe != nil
            || !newRecipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Aperçu des apports, seulement quand l'unité en porte : une « pièce » ne
    /// dit rien de la masse.
    private var preview: NutritionFacts? {
        guard destination == .recipe, unit.dimension != .count, quantity > 0 else { return nil }
        return NutritionCalculator.nutrition(
            for: food.nutritionPer100g,
            quantityInGrams: quantity * unit.baseUnitFactor
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name).font(.headline)
                    if let brand = food.brand {
                        Text(brand).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Picker("Destination", selection: $destination) {
                    ForEach(Destination.allCases) { destination in
                        Text(destination.title).tag(destination)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if destination == .recipe {
                Section("Recette") {
                    Picker("Recette", selection: $selectedRecipeID) {
                        Text("Nouvelle recette…").tag(UUID?.none)
                        ForEach(recipes) { recipe in
                            Text(recipe.name).tag(UUID?.some(recipe.id))
                        }
                    }

                    if isCreatingRecipe {
                        TextField("Nom de la recette", text: $newRecipeName)
                    }
                }
            }

            Section("Quantité") {
                HStack {
                    TextField("1", text: $quantityText)
                        .keyboardType(.decimalPad)
                    Picker("Unité", selection: $unit) {
                        ForEach(MeasurementUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .labelsHidden()
                }
            }

            if let preview {
                Section("Apports dans la recette") {
                    NutritionBreakdownView(facts: preview)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(Color.alert)
                }
            }
        }
        .navigationTitle("Ajouter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter", action: save)
                    .disabled(!canSave)
            }
        }
        .onChange(of: destination) { _, newValue in
            // Une pièce sur la liste de courses, des grammes dans une recette.
            unit = newValue == .shoppingList ? .piece : .gram
            quantityText = newValue == .shoppingList ? "1" : "100"
        }
    }

    private func save() {
        do {
            switch destination {
            case .shoppingList:
                try ShoppingListService(context: context).addManualItem(
                    name: food.name,
                    quantity: quantity,
                    unit: unit
                )
            case .recipe:
                let service = RecipeService(context: context)
                let recipe = selectedRecipe ?? service.create(
                    name: newRecipeName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                service.addIngredient(to: recipe, from: food, quantity: quantity, unit: unit)
            }
            dismiss()
        } catch {
            errorMessage = "L'ajout n'a pas pu être enregistré. Réessaie."
        }
    }
}

#Preview {
    NavigationStack {
        AddProductToListSheet(food: PreviewData.sampleRemoteFoods[0])
    }
    .modelContainer(PreviewData.container())
}
