import SwiftUI

/// Calorie ring, macro targets and macro split for the selected day.
struct DailySummaryCard: View {
    let summary: DailyNutritionSummary
    /// Dépense lue dans Apple Santé. `nil` quand la donnée n'est pas lisible :
    /// la ligne disparaît alors plutôt que d'afficher un zéro trompeur.
    var activeEnergyBurned: Double?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                CalorieRing(consumed: summary.consumed.calories, goal: summary.goals.calories)
                    .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Macro.allCases) { macro in
                        MacroProgressBar(
                            macro: macro,
                            consumed: summary.consumedGrams(for: macro),
                            target: summary.targetGrams(for: macro)
                        )
                    }
                }
            }

            HStack(spacing: 12) {
                remainingLabel
                if let activeEnergyBurned {
                    Text("·").foregroundStyle(.tertiary)
                    Label(
                        "\(Int(activeEnergyBurned.rounded())) kcal brûlées",
                        systemImage: "figure.run"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }

            if summary.consumed.calories > 0 {
                Divider()
                MacroDistributionBar(facts: summary.consumed)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var remainingLabel: some View {
        if summary.isOverCalorieGoal {
            Label(
                "Objectif dépassé de \(Int((summary.consumed.calories - summary.goals.calories).rounded())) kcal",
                systemImage: "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(.orange)
        } else {
            Label(
                "Il te reste \(Int(summary.remainingCalories.rounded())) kcal",
                systemImage: "flame"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DailySummaryCard(
        summary: DailyNutritionSummary(
            date: .now,
            consumed: NutritionFacts(calories: 1420, proteins: 88, carbohydrates: 150, fats: 48),
            goals: .default,
            entryCount: 5
        ),
        activeEnergyBurned: 620
    )
    .padding()
}
