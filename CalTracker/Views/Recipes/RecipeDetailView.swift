import SwiftData
import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var context
    @State private var isPresentingEdit = false
    @State private var isPresentingLog = false
    @State private var confirmation: String?

    private var sortedIngredients: [RecipeIngredient] {
        recipe.ingredients.sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        List {
            if !recipe.summary.isEmpty {
                Section {
                    Text(recipe.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Pour \(recipe.servings) portions") {
                if recipe.hasNutritionData {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Par portion") {
                            Text(QuantityFormatter.calories(recipe.nutritionPerServing.calories))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        MacroDistributionBar(facts: recipe.nutritionPerServing)
                    }
                    .padding(.vertical, 4)

                    NutritionBreakdownView(facts: recipe.nutritionPerServing)
                } else {
                    Text("Ajoute des ingrédients issus d'Open Food Facts pour calculer les macros.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Ingrédients") {
                if sortedIngredients.isEmpty {
                    Text("Aucun ingrédient pour le moment.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedIngredients) { ingredient in
                        IngredientRow(ingredient: ingredient)
                    }
                }
            }

            if !recipe.instructions.isEmpty {
                Section("Préparation") {
                    Text(recipe.instructions)
                        .font(.body)
                }
            }

            Section {
                Button {
                    addToShoppingList()
                } label: {
                    Label("Ajouter à la liste de courses", systemImage: "cart.badge.plus")
                }

                Button {
                    isPresentingLog = true
                } label: {
                    Label("Ajouter au journal", systemImage: "plus.circle")
                }
                .disabled(!recipe.hasNutritionData)

                Button {
                    RecipeService(context: context).duplicate(recipe)
                    confirmation = "Recette dupliquée."
                } label: {
                    Label("Dupliquer", systemImage: "doc.on.doc")
                }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifier") { isPresentingEdit = true }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            NavigationStack {
                RecipeFormView(recipe: recipe)
            }
        }
        .sheet(isPresented: $isPresentingLog) {
            NavigationStack {
                LogRecipeSheet(recipe: recipe)
            }
            .presentationDetents([.medium])
        }
        .alert(
            confirmation ?? "",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })
        ) {
            Button("OK", role: .cancel) { confirmation = nil }
        }
    }

    private func addToShoppingList() {
        do {
            try ShoppingListService(context: context).generate(
                from: [RecipeSelection(recipe: recipe)],
                mode: .merge
            )
            confirmation = "Ingrédients ajoutés à la liste de courses."
        } catch {
            confirmation = "La liste n'a pas pu être mise à jour."
        }
    }
}

struct IngredientRow: View {
    let ingredient: RecipeIngredient

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ingredient.name)
                    if ingredient.isPantryStaple {
                        Image(systemName: "cabinet")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                if ingredient.hasNutritionData {
                    MacroSummaryLine(facts: ingredient.nutritionContribution)
                }
            }
            Spacer()
            Text(ingredient.quantityDescription)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

/// Logs a number of servings of a recipe into the journal.
private struct LogRecipeSheet: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var servings: Double = 1
    @State private var meal: MealType = .dinner
    @State private var date: Date = .now

    private var preview: NutritionFacts {
        recipe.nutritionPerServing.scaled(by: servings)
    }

    var body: some View {
        Form {
            Section("Portions") {
                Stepper(value: $servings, in: 0.5...10, step: 0.5) {
                    Text("\(QuantityFormatter.string(from: servings)) portion(s)")
                        .monospacedDigit()
                }
            }

            Section("Repas") {
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.orderedCases) { meal in
                        Text(meal.localizedName).tag(meal)
                    }
                }
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
            }

            Section("Apports") {
                NutritionBreakdownView(facts: preview)
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter") {
                    JournalService(context: context).log(
                        recipe: recipe,
                        servings: servings,
                        meal: meal,
                        on: date
                    )
                    dismiss()
                }
            }
        }
        .onAppear {
            meal = MealType.suggested(for: .now)
        }
    }
}
