import Foundation
import SwiftData

struct RecipeService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func allRecipes() throws -> [Recipe] {
        try context.fetch(
            FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.name)])
        )
    }

    @discardableResult
    func create(name: String, servings: Int = 2) -> Recipe {
        let recipe = Recipe(name: name, servings: servings)
        context.insert(recipe)
        return recipe
    }

    func delete(_ recipe: Recipe) {
        context.delete(recipe)
    }

    func toggleFavorite(_ recipe: Recipe) {
        recipe.isFavorite.toggle()
    }

    @discardableResult
    func addIngredient(
        to recipe: Recipe,
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        isPantryStaple: Bool = false,
        gramsPerPiece: Double? = nil,
        nutritionPer100g: NutritionFacts? = nil,
        barcode: String? = nil
    ) -> RecipeIngredient {
        let ingredient = RecipeIngredient(
            name: name,
            quantity: quantity,
            unit: unit,
            sortIndex: nextSortIndex(in: recipe),
            barcode: barcode,
            isPantryStaple: isPantryStaple,
            gramsPerPiece: gramsPerPiece,
            nutritionPer100g: nutritionPer100g
        )
        ingredient.recipe = recipe
        recipe.ingredients.append(ingredient)
        context.insert(ingredient)
        return ingredient
    }

    /// Adds an ingredient from an Open Food Facts result, carrying its macros
    /// over so the recipe can compute its own nutrition.
    @discardableResult
    func addIngredient(
        to recipe: Recipe,
        from remote: RemoteFood,
        quantity: Double,
        unit: MeasurementUnit
    ) -> RecipeIngredient {
        addIngredient(
            to: recipe,
            name: remote.name,
            quantity: quantity,
            unit: unit,
            nutritionPer100g: remote.nutritionPer100g,
            barcode: remote.barcode
        )
    }

    func removeIngredient(_ ingredient: RecipeIngredient, from recipe: Recipe) {
        recipe.ingredients.removeAll { $0.id == ingredient.id }
        context.delete(ingredient)
        reindex(recipe)
    }

    /// Duplicates a recipe, ingredients included, as a starting point for a variant.
    @discardableResult
    func duplicate(_ recipe: Recipe) -> Recipe {
        let copy = Recipe(
            name: "\(recipe.name) (copie)",
            summary: recipe.summary,
            instructions: recipe.instructions,
            servings: recipe.servings,
            preparationMinutes: recipe.preparationMinutes
        )
        context.insert(copy)
        for ingredient in recipe.ingredients.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            addIngredient(
                to: copy,
                name: ingredient.name,
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                isPantryStaple: ingredient.isPantryStaple,
                gramsPerPiece: ingredient.gramsPerPiece,
                nutritionPer100g: ingredient.nutritionPer100g,
                barcode: ingredient.barcode
            )
        }
        return copy
    }

    private func nextSortIndex(in recipe: Recipe) -> Int {
        (recipe.ingredients.map(\.sortIndex).max() ?? -1) + 1
    }

    private func reindex(_ recipe: Recipe) {
        for (index, ingredient) in recipe.ingredients.sorted(by: { $0.sortIndex < $1.sortIndex }).enumerated() {
            ingredient.sortIndex = index
        }
    }
}
