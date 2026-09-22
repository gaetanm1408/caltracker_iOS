import Foundation
import SwiftData

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var name: String
    var summary: String
    var instructions: String
    var servings: Int
    var preparationMinutes: Int
    var createdAt: Date
    var isFavorite: Bool

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient] = []

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        instructions: String = "",
        servings: Int = 2,
        preparationMinutes: Int = 0,
        isFavorite: Bool = false,
        createdAt: Date = .now,
        ingredients: [RecipeIngredient] = []
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.instructions = instructions
        self.servings = max(1, servings)
        self.preparationMinutes = preparationMinutes
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.ingredients = ingredients
    }

    /// Nutrition of the whole recipe, i.e. every ingredient added up.
    var totalNutrition: NutritionFacts {
        NutritionCalculator.total(of: ingredients.map(\.nutritionContribution))
    }

    var nutritionPerServing: NutritionFacts {
        totalNutrition.scaled(by: 1 / Double(max(1, servings)))
    }

    /// True when at least one ingredient carries usable nutrition data.
    var hasNutritionData: Bool {
        ingredients.contains { $0.hasNutritionData }
    }
}
