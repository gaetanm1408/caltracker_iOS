import Foundation
import SwiftData

/// One line of the daily journal: a quantity of a product eaten at a given meal.
///
/// Nutrition is snapshotted at insertion time so that editing or deleting the
/// referenced product later never rewrites the user's history.
@Model
final class FoodEntry {
    #Index<FoodEntry>([\.day], [\.consumedAt])

    @Attribute(.unique) var id: UUID
    var consumedAt: Date
    /// Start of the day `consumedAt` belongs to; lets the journal fetch a day
    /// with an equality predicate instead of a range scan.
    var day: Date
    var mealRawValue: String
    var quantityInGrams: Double
    var productNameSnapshot: String
    var brandSnapshot: String?

    var caloriesPer100g: Double
    var proteinsPer100g: Double
    var carbohydratesPer100g: Double
    var fatsPer100g: Double
    var fibersPer100g: Double
    var sugarsPer100g: Double
    var saturatedFatsPer100g: Double
    var saltPer100g: Double

    var product: FoodProduct?

    init(
        id: UUID = UUID(),
        product: FoodProduct?,
        productNameSnapshot: String,
        brandSnapshot: String? = nil,
        nutritionPer100g: NutritionFacts,
        quantityInGrams: Double,
        meal: MealType,
        consumedAt: Date = .now,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.product = product
        self.productNameSnapshot = productNameSnapshot
        self.brandSnapshot = brandSnapshot
        self.quantityInGrams = quantityInGrams
        self.mealRawValue = meal.rawValue
        self.consumedAt = consumedAt
        self.day = calendar.startOfDay(for: consumedAt)
        self.caloriesPer100g = nutritionPer100g.calories
        self.proteinsPer100g = nutritionPer100g.proteins
        self.carbohydratesPer100g = nutritionPer100g.carbohydrates
        self.fatsPer100g = nutritionPer100g.fats
        self.fibersPer100g = nutritionPer100g.fibers
        self.sugarsPer100g = nutritionPer100g.sugars
        self.saturatedFatsPer100g = nutritionPer100g.saturatedFats
        self.saltPer100g = nutritionPer100g.salt
    }

    convenience init(
        product: FoodProduct,
        quantityInGrams: Double,
        meal: MealType,
        consumedAt: Date = .now,
        calendar: Calendar = .current
    ) {
        self.init(
            product: product,
            productNameSnapshot: product.name,
            brandSnapshot: product.brand,
            nutritionPer100g: product.nutritionPer100g,
            quantityInGrams: quantityInGrams,
            meal: meal,
            consumedAt: consumedAt,
            calendar: calendar
        )
    }

    var meal: MealType {
        get { MealType(rawValue: mealRawValue) ?? .snack }
        set { mealRawValue = newValue.rawValue }
    }

    var nutritionPer100g: NutritionFacts {
        NutritionFacts(
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

    /// Nutrition actually consumed, i.e. the per-100 g values scaled to the
    /// logged quantity.
    var consumedNutrition: NutritionFacts {
        NutritionCalculator.nutrition(for: nutritionPer100g, quantityInGrams: quantityInGrams)
    }

    func move(to date: Date, calendar: Calendar = .current) {
        consumedAt = date
        day = calendar.startOfDay(for: date)
    }
}
