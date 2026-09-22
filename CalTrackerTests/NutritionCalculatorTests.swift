import Foundation
import Testing

@testable import CalTracker

@Suite("Calcul des macros")
struct NutritionCalculatorTests {
    private let oats = NutritionFacts(
        calories: 372, proteins: 13, carbohydrates: 59, fats: 7, fibers: 10
    )

    @Test("Les valeurs pour 100 g sont mises à l'échelle de la quantité")
    func scalesToQuantity() {
        let facts = NutritionCalculator.nutrition(for: oats, quantityInGrams: 50)

        #expect(facts.calories == 186)
        #expect(facts.proteins == 6.5)
        #expect(facts.carbohydrates == 29.5)
        #expect(facts.fats == 3.5)
    }

    @Test("Une quantité nulle ou négative ne rapporte aucun apport")
    func rejectsNonPositiveQuantity() {
        #expect(NutritionCalculator.nutrition(for: oats, quantityInGrams: 0) == .zero)
        #expect(NutritionCalculator.nutrition(for: oats, quantityInGrams: -20) == .zero)
    }

    @Test("Les apports s'additionnent")
    func addsFacts() {
        let total = NutritionCalculator.total(of: [
            NutritionFacts(calories: 100, proteins: 10, carbohydrates: 5, fats: 2),
            NutritionFacts(calories: 250, proteins: 5, carbohydrates: 30, fats: 8)
        ])

        #expect(total.calories == 350)
        #expect(total.proteins == 15)
        #expect(total.carbohydrates == 35)
        #expect(total.fats == 10)
    }

    @Test("La répartition des macros totalise 100 %")
    func macroDistributionSumsToOne() {
        let facts = NutritionFacts(calories: 500, proteins: 25, carbohydrates: 50, fats: 20)
        let distribution = NutritionCalculator.macroDistribution(in: facts)
        let sum = distribution.values.reduce(0, +)

        #expect(abs(sum - 1) < 0.0001)
        // 100 kcal de protéines sur 100 + 200 + 180 = 480 kcal
        #expect(abs((distribution[.proteins] ?? 0) - 100.0 / 480.0) < 0.0001)
        #expect(abs((distribution[.fats] ?? 0) - 180.0 / 480.0) < 0.0001)
    }

    @Test("Un repas sans macro ne provoque pas de division par zéro")
    func handlesEmptyDistribution() {
        let distribution = NutritionCalculator.macroDistribution(in: .zero)

        #expect(distribution[.proteins] == 0)
        #expect(distribution[.carbohydrates] == 0)
        #expect(distribution[.fats] == 0)
    }

    @Test("La progression est bornée entre 0 et 1")
    func clampsProgress() {
        #expect(NutritionCalculator.progress(consumed: 500, goal: 2000) == 0.25)
        #expect(NutritionCalculator.progress(consumed: 2500, goal: 2000) == 1)
        #expect(NutritionCalculator.progress(consumed: 100, goal: 0) == 0)
    }

    @Test("Les cibles en grammes découlent de la répartition choisie")
    func derivesMacroTargets() {
        let goals = NutritionGoals(
            calories: 2000,
            proteinPercentage: 0.30,
            carbohydratePercentage: 0.40,
            fatPercentage: 0.30
        )

        #expect(goals.targetGrams(for: .proteins) == 150)      // 600 kcal / 4
        #expect(goals.targetGrams(for: .carbohydrates) == 200) // 800 kcal / 4
        #expect(abs(goals.targetGrams(for: .fats) - 66.67) < 0.01)
        #expect(goals.isBalanced)
    }

    @Test("Le résumé quotidien expose le restant et le dépassement")
    func buildsDailySummary() {
        let summary = DailyNutritionSummary(
            date: .now,
            consumed: NutritionFacts(calories: 2200, proteins: 160, carbohydrates: 180, fats: 70),
            goals: .default,
            entryCount: 4
        )

        #expect(summary.isOverCalorieGoal)
        #expect(summary.remainingCalories == 0)
        #expect(summary.calorieProgress == 1)
        #expect(summary.remainingGrams(for: .proteins) == 0)
        #expect(summary.consumedGrams(for: .carbohydrates) == 180)
    }

    @Test("Les calories sont recalculées quand seules les macros sont connues")
    func estimatesCaloriesFromMacros() {
        let facts = NutritionFacts(calories: 0, proteins: 10, carbohydrates: 20, fats: 5)

        #expect(facts.estimatedCaloriesFromMacros == 165)
    }
}
