import Foundation
import SwiftData

/// An ingredient line inside a recipe.
///
/// The nutrition values are copied from the Open Food Facts product they were
/// imported from, so a recipe keeps its macros even offline.
@Model
final class RecipeIngredient {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double
    var unitRawValue: String
    var sortIndex: Int
    var barcode: String?
    var isPantryStaple: Bool

    var caloriesPer100g: Double
    var proteinsPer100g: Double
    var carbohydratesPer100g: Double
    var fatsPer100g: Double
    var fibersPer100g: Double
    var sugarsPer100g: Double
    var saturatedFatsPer100g: Double
    var saltPer100g: Double
    var hasNutritionData: Bool

    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        sortIndex: Int = 0,
        barcode: String? = nil,
        isPantryStaple: Bool = false,
        nutritionPer100g: NutritionFacts? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitRawValue = unit.rawValue
        self.sortIndex = sortIndex
        self.barcode = barcode
        self.isPantryStaple = isPantryStaple
        let facts = nutritionPer100g ?? .zero
        self.hasNutritionData = nutritionPer100g != nil
        self.caloriesPer100g = facts.calories
        self.proteinsPer100g = facts.proteins
        self.carbohydratesPer100g = facts.carbohydrates
        self.fatsPer100g = facts.fats
        self.fibersPer100g = facts.fibers
        self.sugarsPer100g = facts.sugars
        self.saturatedFatsPer100g = facts.saturatedFats
        self.saltPer100g = facts.salt
    }

    convenience init(
        product: FoodProduct,
        quantity: Double,
        unit: MeasurementUnit,
        sortIndex: Int = 0
    ) {
        self.init(
            name: product.name,
            quantity: quantity,
            unit: unit,
            sortIndex: sortIndex,
            barcode: product.barcode,
            nutritionPer100g: product.nutritionPer100g
        )
    }

    var unit: MeasurementUnit {
        get { MeasurementUnit(rawValue: unitRawValue) ?? .gram }
        set { unitRawValue = newValue.rawValue }
    }

    var nutritionPer100g: NutritionFacts? {
        guard hasNutritionData else { return nil }
        return NutritionFacts(
            calories: caloriesPer100g,
            proteins: proteinsPer100g,
            carbohydrates: carbohydratesPer100g,
            fats: fatsPer100g,
            fibers: fibersPer100g,
            sugars: sugarsPer100g,
            saturatedFats: saturatedFatsPer100g,
            salt: saltPer100g
        )
    }

    /// Quantity converted to grams, `nil` for units that carry no mass
    /// information (pieces).
    var quantityInGrams: Double? {
        switch unit.dimension {
        case .mass, .volume:
            // 1 ml of a household liquid is treated as 1 g, the approximation
            // Open Food Facts itself makes for its per-100 ml values.
            return quantity * unit.baseUnitFactor
        case .count:
            return nil
        }
    }

    /// What this ingredient adds to the recipe's totals.
    var nutritionContribution: NutritionFacts {
        guard let nutritionPer100g, let quantityInGrams else { return .zero }
        return NutritionCalculator.nutrition(for: nutritionPer100g, quantityInGrams: quantityInGrams)
    }

    var quantityDescription: String {
        "\(QuantityFormatter.string(from: quantity)) \(unit.displayName)"
    }
}
