import Foundation
import SwiftData

/// Daily targets the journal compares consumption against.
///
/// A single instance is kept in the store; `UserProfile.current(in:)` creates
/// it on first launch.
@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID

    // Objectifs saisis à la main, utilisés tant que le calcul automatique
    // n'est pas activé.
    var dailyCalorieGoal: Double
    var proteinPercentage: Double
    var carbohydratePercentage: Double
    var fatPercentage: Double

    // Mesures corporelles. Valeurs par défaut hors bornes plausibles : elles
    // signalent un profil que l'utilisateur n'a pas encore renseigné.
    var weightInKilograms: Double = 0
    var heightInCentimeters: Double = 0
    var age: Int = 0
    var sexRawValue: String = BiologicalSex.female.rawValue
    var activityLevelRawValue: String = ActivityLevel.moderate.rawValue
    var weightGoalRawValue: String = WeightGoal.maintenance.rawValue

    /// Faux par défaut, pour que la mise à jour ne change rien aux objectifs
    /// déjà en place.
    var usesCalculatedGoal: Bool = false

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

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRawValue) ?? .female }
        set { sexRawValue = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRawValue) ?? .moderate }
        set { activityLevelRawValue = newValue.rawValue }
    }

    var weightGoal: WeightGoal {
        get { WeightGoal(rawValue: weightGoalRawValue) ?? .maintenance }
        set { weightGoalRawValue = newValue.rawValue }
    }

    var measurements: BodyMeasurements {
        get {
            BodyMeasurements(
                weightInKilograms: weightInKilograms,
                heightInCentimeters: heightInCentimeters,
                age: age,
                sex: sex
            )
        }
        set {
            weightInKilograms = newValue.weightInKilograms
            heightInCentimeters = newValue.heightInCentimeters
            age = newValue.age
            sex = newValue.sex
        }
    }

    /// Le calcul n'est possible qu'une fois les mesures renseignées.
    var canCalculateGoal: Bool { measurements.isComplete }

    var basalMetabolicRate: Double {
        EnergyCalculator.basalMetabolicRate(for: measurements)
    }

    var totalDailyEnergyExpenditure: Double {
        EnergyCalculator.totalDailyEnergyExpenditure(for: measurements, activity: activityLevel)
    }

    /// Objectifs effectifs : calculés à partir du profil quand c'est demandé et
    /// possible, saisis à la main sinon.
    var goals: NutritionGoals {
        guard usesCalculatedGoal, canCalculateGoal else {
            return NutritionGoals(
                calories: dailyCalorieGoal,
                proteinPercentage: proteinPercentage,
                carbohydratePercentage: carbohydratePercentage,
                fatPercentage: fatPercentage
            )
        }
        return EnergyCalculator.goals(
            for: measurements,
            activity: activityLevel,
            goal: weightGoal
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
