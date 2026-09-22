import Foundation

/// Pure nutrition arithmetic. Deliberately free of SwiftData and SwiftUI so it
/// can be unit tested on its own.
enum NutritionCalculator {
    /// Scales per-100 g values to an arbitrary quantity.
    static func nutrition(for per100g: NutritionFacts, quantityInGrams: Double) -> NutritionFacts {
        guard quantityInGrams > 0 else { return .zero }
        return per100g.scaled(by: quantityInGrams / 100)
    }

    static func total(of facts: [NutritionFacts]) -> NutritionFacts {
        facts.reduce(.zero, +)
    }

    static func total(of entries: [FoodEntry]) -> NutritionFacts {
        total(of: entries.map(\.consumedNutrition))
    }

    /// Calories provided by a macro for the given facts.
    static func calories(from macro: Macro, in facts: NutritionFacts) -> Double {
        macro.grams(in: facts) * macro.caloriesPerGram
    }

    /// Share of the energy each macro accounts for, summing to 1.
    ///
    /// Computed from the macros themselves rather than the declared energy, so
    /// the three shares always add up even when a product's energy value is
    /// inconsistent with its macros.
    static func macroDistribution(in facts: NutritionFacts) -> [Macro: Double] {
        let totals = Macro.allCases.map { ($0, calories(from: $0, in: facts)) }
        let sum = totals.reduce(0) { $0 + $1.1 }
        guard sum > 0 else {
            return Dictionary(uniqueKeysWithValues: Macro.allCases.map { ($0, 0.0) })
        }
        return Dictionary(uniqueKeysWithValues: totals.map { ($0.0, $0.1 / sum) })
    }

    /// Ratio of a goal already reached, clamped to [0, 1] for gauge rendering.
    static func progress(consumed: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(consumed / goal, 0), 1)
    }

    static func remaining(consumed: Double, goal: Double) -> Double {
        max(goal - consumed, 0)
    }
}

/// Everything the journal header needs for one day, computed once per render.
struct DailyNutritionSummary: Equatable, Sendable {
    let date: Date
    let consumed: NutritionFacts
    let goals: NutritionGoals
    let entryCount: Int

    init(date: Date, consumed: NutritionFacts, goals: NutritionGoals, entryCount: Int) {
        self.date = date
        self.consumed = consumed
        self.goals = goals
        self.entryCount = entryCount
    }

    static func make(date: Date, entries: [FoodEntry], goals: NutritionGoals) -> DailyNutritionSummary {
        DailyNutritionSummary(
            date: date,
            consumed: NutritionCalculator.total(of: entries),
            goals: goals,
            entryCount: entries.count
        )
    }

    var calorieProgress: Double {
        NutritionCalculator.progress(consumed: consumed.calories, goal: goals.calories)
    }

    var remainingCalories: Double {
        NutritionCalculator.remaining(consumed: consumed.calories, goal: goals.calories)
    }

    var isOverCalorieGoal: Bool {
        consumed.calories > goals.calories
    }

    func consumedGrams(for macro: Macro) -> Double {
        macro.grams(in: consumed)
    }

    func targetGrams(for macro: Macro) -> Double {
        goals.targetGrams(for: macro)
    }

    func progress(for macro: Macro) -> Double {
        NutritionCalculator.progress(consumed: consumedGrams(for: macro), goal: targetGrams(for: macro))
    }

    func remainingGrams(for macro: Macro) -> Double {
        NutritionCalculator.remaining(consumed: consumedGrams(for: macro), goal: targetGrams(for: macro))
    }

    var macroDistribution: [Macro: Double] {
        NutritionCalculator.macroDistribution(in: consumed)
    }
}
