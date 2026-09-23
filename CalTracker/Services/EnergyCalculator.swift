import Foundation

/// Dépense énergétique et objectif calorique. Pure arithmétique, sans
/// SwiftData ni SwiftUI, pour rester testable isolément.
enum EnergyCalculator {
    /// Métabolisme de base selon Mifflin-St Jeor, l'équation retenue par les
    /// recommandations actuelles comme la plus fiable sans mesure de masse
    /// grasse.
    static func basalMetabolicRate(for measurements: BodyMeasurements) -> Double {
        guard measurements.isComplete else { return 0 }
        return 10 * measurements.weightInKilograms
            + 6.25 * measurements.heightInCentimeters
            - 5 * Double(measurements.age)
            + measurements.sex.basalOffset
    }

    /// Dépense totale sur une journée, activité de fond comprise.
    static func totalDailyEnergyExpenditure(
        for measurements: BodyMeasurements,
        activity: ActivityLevel
    ) -> Double {
        basalMetabolicRate(for: measurements) * activity.multiplier
    }

    /// Objectif calorique visé une fois l'écart de l'objectif appliqué.
    ///
    /// Un plancher au métabolisme de base évite de proposer un objectif sous
    /// lequel le corps ne couvre plus ses fonctions vitales.
    static func calorieTarget(
        for measurements: BodyMeasurements,
        activity: ActivityLevel,
        goal: WeightGoal
    ) -> Double {
        let expenditure = totalDailyEnergyExpenditure(for: measurements, activity: activity)
        guard expenditure > 0 else { return 0 }

        let adjusted = expenditure * (1 + goal.calorieAdjustment)
        let floor = basalMetabolicRate(for: measurements)
        return (max(adjusted, floor) / 10).rounded() * 10
    }

    /// Objectifs complets — calories et répartition des macros — déduits du
    /// profil.
    static func goals(
        for measurements: BodyMeasurements,
        activity: ActivityLevel,
        goal: WeightGoal
    ) -> NutritionGoals {
        let split = goal.macroSplit
        return NutritionGoals(
            calories: calorieTarget(for: measurements, activity: activity, goal: goal),
            proteinPercentage: split.protein,
            carbohydratePercentage: split.carbohydrate,
            fatPercentage: split.fat
        )
    }

    /// Objectif du jour rehaussé de l'énergie réellement dépensée en activité.
    ///
    /// Le niveau d'activité déclaré couvre déjà une part de l'exercice ; seule
    /// la dépense au-delà de ce forfait est ajoutée, sans quoi une sortie
    /// longue serait comptée deux fois.
    static func adjustedCalorieTarget(
        base: NutritionGoals,
        activeEnergyBurned: Double,
        activity: ActivityLevel,
        measurements: BodyMeasurements
    ) -> Double {
        guard activeEnergyBurned > 0 else { return base.calories }

        let basal = basalMetabolicRate(for: measurements)
        let alreadyCounted = basal * (activity.multiplier - 1)
        let surplus = max(activeEnergyBurned - alreadyCounted, 0)
        return ((base.calories + surplus) / 10).rounded() * 10
    }
}
