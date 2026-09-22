import Foundation
import SwiftData

/// A food item imported from Open Food Facts and cached locally. Nutrition
/// values are always stored per 100 g / 100 ml.
@Model
final class FoodProduct {
    #Index<FoodProduct>([\.barcode], [\.name])

    @Attribute(.unique) var id: UUID
    var barcode: String?
    var name: String
    var brand: String?
    var imageURLString: String?
    var servingSizeInGrams: Double?
    var createdAt: Date
    var lastUsedAt: Date?

    var calories: Double
    var proteins: Double
    var carbohydrates: Double
    var fats: Double
    var fibers: Double
    var sugars: Double
    var saturatedFats: Double
    var salt: Double

    /// Nullify rather than cascade: past journal entries keep their own
    /// nutrition snapshot and must survive the deletion of the product.
    @Relationship(deleteRule: .nullify, inverse: \FoodEntry.product)
    var entries: [FoodEntry] = []

    init(
        id: UUID = UUID(),
        barcode: String? = nil,
        name: String,
        brand: String? = nil,
        imageURLString: String? = nil,
        servingSizeInGrams: Double? = nil,
        nutritionPer100g: NutritionFacts,
        createdAt: Date = .now,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.imageURLString = imageURLString
        self.servingSizeInGrams = servingSizeInGrams
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.calories = nutritionPer100g.calories
        self.proteins = nutritionPer100g.proteins
        self.carbohydrates = nutritionPer100g.carbohydrates
        self.fats = nutritionPer100g.fats
        self.fibers = nutritionPer100g.fibers
        self.sugars = nutritionPer100g.sugars
        self.saturatedFats = nutritionPer100g.saturatedFats
        self.salt = nutritionPer100g.salt
    }

    var nutritionPer100g: NutritionFacts {
        get {
            NutritionFacts(
                calories: calories,
                proteins: proteins,
                carbohydrates: carbohydrates,
                fats: fats,
                fibers: fibers,
                sugars: sugars,
                saturatedFats: saturatedFats,
                salt: salt
            )
        }
        set {
            calories = newValue.calories
            proteins = newValue.proteins
            carbohydrates = newValue.carbohydrates
            fats = newValue.fats
            fibers = newValue.fibers
            sugars = newValue.sugars
            saturatedFats = newValue.saturatedFats
            salt = newValue.salt
        }
    }

    var imageURL: URL? {
        imageURLString.flatMap(URL.init(string:))
    }
}
