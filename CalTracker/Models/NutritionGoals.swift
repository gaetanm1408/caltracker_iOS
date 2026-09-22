import Foundation
import SwiftData

/// Daily targets the journal compares consumption against.
///
/// A single instance is kept in the store; `UserProfile.current(in:)` creates
/// it on first launch.
@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var dailyCalorieGoal: Double
    var proteinPercentage: Double
    var carbohydratePercentage: Double
    var fatPercentage: Double
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        dailyCalorieGoal: Double = 2000,
        proteinPercentage: Double = 0.30,
        carbohydratePercentage: Double = 0.40,
        fatPercentage: Double = 0.30,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.dailyCalorieGoal = dailyCalorieGoal
        self.proteinPercentage = proteinPercentage
        self.carbohydratePercentage = carbohydratePercentage
        self.fatPercentage = fatPercentage
        self.updatedAt = updatedAt
    }

    var goals: NutritionGoals {
        NutritionGoals(
            calories: dailyCalorieGoal,
            proteinPercentage: proteinPercentage,
            carbohydratePercentage: carbohydratePercentage,
            fatPercentage: fatPercentage
        )
    }
}

/// Value type carrying the daily targets, derived from a calorie goal and a
/// macro split.
struct NutritionGoals: Equatable, Sendable {
    var calories: Double
    var proteinPercentage: Double
    var carbohydratePercentage: Double
    var fatPercentage: Double

    static let `default` = NutritionGoals(
        calories: 2000,
        proteinPercentage: 0.30,
        carbohydratePercentage: 0.40,
        fatPercentage: 0.30
    )

    func percentage(for macro: Macro) -> Double {
        switch macro {
        case .proteins: return proteinPercentage
        case .carbohydrates: return carbohydratePercentage
        case .fats: return fatPercentage
        }
    }

    /// Grams of `macro` the split allocates for the day.
    func targetGrams(for macro: Macro) -> Double {
        guard macro.caloriesPerGram > 0 else { return 0 }
        return calories * percentage(for: macro) / macro.caloriesPerGram
    }

    /// The three percentages should add up to 1; used to warn in the settings UI.
    var isBalanced: Bool {
        abs(proteinPercentage + carbohydratePercentage + fatPercentage - 1) < 0.001
    }
}
