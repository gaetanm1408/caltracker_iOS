import Foundation

/// Nutritional values expressed for a 100 g (or 100 ml) reference quantity.
struct NutritionFacts: Codable, Hashable, Sendable {
    var calories: Double
    var proteins: Double
    var carbohydrates: Double
    var fats: Double
    var fibers: Double
    var sugars: Double
    var saturatedFats: Double
    var salt: Double

    init(
        calories: Double = 0,
        proteins: Double = 0,
        carbohydrates: Double = 0,
        fats: Double = 0,
        fibers: Double = 0,
        sugars: Double = 0,
        saturatedFats: Double = 0,
        salt: Double = 0
    ) {
        self.calories = calories
        self.proteins = proteins
        self.carbohydrates = carbohydrates
        self.fats = fats
        self.fibers = fibers
        self.sugars = sugars
        self.saturatedFats = saturatedFats
        self.salt = salt
    }

    static let zero = NutritionFacts()

    /// Energy recomputed from the macronutrients (Atwater factors), used when
    /// Open Food Facts exposes macros without an energy value.
    var estimatedCaloriesFromMacros: Double {
        proteins * 4 + carbohydrates * 4 + fats * 9
    }

    func scaled(by factor: Double) -> NutritionFacts {
        NutritionFacts(
            calories: calories * factor,
            proteins: proteins * factor,
            carbohydrates: carbohydrates * factor,
            fats: fats * factor,
            fibers: fibers * factor,
            sugars: sugars * factor,
            saturatedFats: saturatedFats * factor,
            salt: salt * factor
        )
    }

    static func + (lhs: NutritionFacts, rhs: NutritionFacts) -> NutritionFacts {
        NutritionFacts(
            calories: lhs.calories + rhs.calories,
            proteins: lhs.proteins + rhs.proteins,
            carbohydrates: lhs.carbohydrates + rhs.carbohydrates,
            fats: lhs.fats + rhs.fats,
            fibers: lhs.fibers + rhs.fibers,
            sugars: lhs.sugars + rhs.sugars,
            saturatedFats: lhs.saturatedFats + rhs.saturatedFats,
            salt: lhs.salt + rhs.salt
        )
    }

    static func += (lhs: inout NutritionFacts, rhs: NutritionFacts) {
        lhs = lhs + rhs
    }
}

/// The three macronutrients tracked and displayed across the app.
enum Macro: String, CaseIterable, Identifiable, Sendable {
    case proteins
    case carbohydrates
    case fats

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .proteins: return "Protéines"
        case .carbohydrates: return "Glucides"
        case .fats: return "Lipides"
        }
    }

    var shortName: String {
        switch self {
        case .proteins: return "P"
        case .carbohydrates: return "G"
        case .fats: return "L"
        }
    }

    /// Kilocalories provided by one gram of this macronutrient.
    var caloriesPerGram: Double {
        switch self {
        case .proteins, .carbohydrates: return 4
        case .fats: return 9
        }
    }

    func grams(in facts: NutritionFacts) -> Double {
        switch self {
        case .proteins: return facts.proteins
        case .carbohydrates: return facts.carbohydrates
        case .fats: return facts.fats
        }
    }
}
