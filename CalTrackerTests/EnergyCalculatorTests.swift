import Foundation
import Testing

@testable import CalTracker

@Suite("Dépense énergétique et objectifs")
struct EnergyCalculatorTests {
    private let man = BodyMeasurements(
        weightInKilograms: 80,
        heightInCentimeters: 180,
        age: 30,
        sex: .male
    )
    private let woman = BodyMeasurements(
        weightInKilograms: 65,
        heightInCentimeters: 168,
        age: 30,
        sex: .female
    )

    @Test("Le métabolisme de base suit Mifflin-St Jeor")
    func computesBasalMetabolicRate() {
        // 10×80 + 6,25×180 − 5×30 + 5 = 1780
        #expect(EnergyCalculator.basalMetabolicRate(for: man) == 1780)
        // 10×65 + 6,25×168 − 5×30 − 161 = 1389
        #expect(EnergyCalculator.basalMetabolicRate(for: woman) == 1389)
    }

    @Test("À mesures égales, l'écart entre sexes est celui de l'équation")
    func appliesSexOffset() {
        var sameAsMan = man
        sameAsMan.sex = .female

        let difference = EnergyCalculator.basalMetabolicRate(for: man)
            - EnergyCalculator.basalMetabolicRate(for: sameAsMan)
        #expect(difference == 166)
    }

    @Test("Un profil incomplet ne produit aucun objectif")
    func refusesIncompleteMeasurements() {
        let empty = BodyMeasurements(weightInKilograms: 0, heightInCentimeters: 0, age: 0, sex: .male)

        #expect(!empty.isComplete)
        #expect(EnergyCalculator.basalMetabolicRate(for: empty) == 0)
        #expect(EnergyCalculator.calorieTarget(for: empty, activity: .moderate, goal: .deficit) == 0)
    }

    @Test("Des mesures aberrantes sont écartées")
    func rejectsImplausibleMeasurements() {
        let tooHeavy = BodyMeasurements(weightInKilograms: 500, heightInCentimeters: 180, age: 30, sex: .male)
        let tooShort = BodyMeasurements(weightInKilograms: 70, heightInCentimeters: 40, age: 30, sex: .male)

        #expect(!tooHeavy.isComplete)
        #expect(!tooShort.isComplete)
    }

    @Test("La dépense totale applique le facteur d'activité")
    func appliesActivityMultiplier() {
        let sedentary = EnergyCalculator.totalDailyEnergyExpenditure(for: man, activity: .sedentary)
        let veryHigh = EnergyCalculator.totalDailyEnergyExpenditure(for: man, activity: .veryHigh)

        #expect(sedentary == 1780 * 1.2)
        #expect(veryHigh == 1780 * 1.9)
        #expect(veryHigh > sedentary)
    }

    @Test("Chaque objectif décale la cible dans le bon sens")
    func appliesGoalAdjustment() {
        let maintenance = EnergyCalculator.calorieTarget(for: man, activity: .moderate, goal: .maintenance)
        let deficit = EnergyCalculator.calorieTarget(for: man, activity: .moderate, goal: .deficit)
        let gain = EnergyCalculator.calorieTarget(for: man, activity: .moderate, goal: .gain)

        // 1780 × 1,55 = 2759, arrondi à la dizaine
        #expect(maintenance == 2760)
        #expect(deficit < maintenance)
        #expect(gain > maintenance)
        #expect(abs(deficit - 2759 * 0.8) < 10)
    }

    @Test("La cible ne descend jamais sous le métabolisme de base")
    func neverTargetsBelowBasalRate() {
        // Un sédentaire en déficit : 1,2 × 0,8 = 0,96 de son métabolisme, donc
        // sous le plancher si on appliquait l'écart tel quel.
        let target = EnergyCalculator.calorieTarget(for: man, activity: .sedentary, goal: .deficit)

        #expect(target >= EnergyCalculator.basalMetabolicRate(for: man))
    }

    @Test("Le déficit augmente la part de protéines")
    func favoursProteinInDeficit() {
        let deficit = EnergyCalculator.goals(for: man, activity: .moderate, goal: .deficit)
        let gain = EnergyCalculator.goals(for: man, activity: .moderate, goal: .gain)

        #expect(deficit.proteinPercentage > gain.proteinPercentage)
        #expect(gain.carbohydratePercentage > deficit.carbohydratePercentage)
        #expect(deficit.isBalanced)
        #expect(gain.isBalanced)
    }

}

@Suite("Profil utilisateur")
struct UserProfileGoalTests {
    @Test("Le profil vierge conserve les objectifs saisis à la main")
    func keepsManualGoalsByDefault() {
        let profile = UserProfile(dailyCalorieGoal: 2200)

        #expect(!profile.usesCalculatedGoal)
        #expect(!profile.canCalculateGoal)
        #expect(profile.goals.calories == 2200)
    }

    @Test("Une fois renseigné, le profil calcule ses objectifs")
    func switchesToCalculatedGoals() {
        let profile = UserProfile(dailyCalorieGoal: 2200)
        profile.measurements = BodyMeasurements(
            weightInKilograms: 80, heightInCentimeters: 180, age: 30, sex: .male
        )
        profile.activityLevel = .moderate
        profile.weightGoal = .maintenance
        profile.usesCalculatedGoal = true

        #expect(profile.canCalculateGoal)
        #expect(profile.basalMetabolicRate == 1780)
        #expect(profile.goals.calories == 2760)
    }

    @Test("Le calcul demandé sans mesures retombe sur la saisie manuelle")
    func fallsBackWhenMeasurementsMissing() {
        let profile = UserProfile(dailyCalorieGoal: 1900)
        profile.usesCalculatedGoal = true

        #expect(profile.goals.calories == 1900)
    }
}
