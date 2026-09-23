import Foundation
import SwiftData

enum RecipeCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case meal
    case snack

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .meal: return "Repas"
        case .snack: return "Collation"
        }
    }

    var systemImageName: String {
        switch self {
        case .meal: return "fork.knife"
        case .snack: return "takeoutbag.and.cup.and.straw"
        }
    }
}

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
    /// Distingue un plat d'une collation, ce dont la planification de menus a
    /// besoin pour remplir des journées.
    var categoryRawValue: String = RecipeCategory.meal.rawValue
    /// Matériel réclamé. Vide par défaut, donc réalisable partout : une recette
    /// saisie à la main n'a aucune raison d'être écartée faute d'information.
    var equipmentRawValues: [String] = []

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

    var category: RecipeCategory {
        get { RecipeCategory(rawValue: categoryRawValue) ?? .meal }
        set { categoryRawValue = newValue.rawValue }
    }

    var equipment: Set<CookingEquipment> {
        get { Set(equipmentRawValues.compactMap(CookingEquipment.init(rawValue:))) }
        set { equipmentRawValues = newValue.map(\.rawValue).sorted() }
    }

    /// Noms d'ingrédients normalisés, pour confronter la recette aux aliments
    /// que l'utilisateur ne veut pas voir.
    var normalizedIngredientNames: Set<String> {
        Set(ingredients.map { ShoppingListBuilder.normalize($0.name) })
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
