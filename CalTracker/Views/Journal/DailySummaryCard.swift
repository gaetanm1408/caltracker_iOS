import SwiftUI

/// Anneau des calories, objectifs par macro et répartition du jour.
struct DailySummaryCard: View {
    let summary: DailyNutritionSummary
    /// Dépense lue dans Apple Santé. `nil` quand la donnée n'est pas lisible :
    /// la ligne disparaît alors plutôt que d'afficher un zéro trompeur.
    var activeEnergyBurned: Double?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                CalorieRing(consumed: summary.consumed.calories, goal: summary.goals.calories)
                    .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Macro.allCases) { macro in
                        MacroProgressBar(
                            macro: macro,
                            consumed: summary.consumedGrams(for: macro),
                            target: summary.targetGrams(for: macro)
                        )
                    }
                }
            }

            footer

            if summary.consumed.calories > 0 {
                Divider()
                MacroDistributionBar(facts: summary.consumed)
            }
        }
        .padding(.vertical, 10)
    }

    /// Ce qu'il reste à gauche, ce qui a été brûlé à droite : deux informations
    /// distinctes, que l'ancienne ligne collait bout à bout.
    private var footer: some View {
        HStack(spacing: 12) {
            remainingLabel
            Spacer(minLength: 8)
            if let activeEnergyBurned {
                Label(
                    "\(Int(activeEnergyBurned.rounded())) kcal brûlées",
                    systemImage: "figure.run"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var remainingLabel: some View {
        if summary.isOverCalorieGoal {
            Label {
                Text("Dépassé de \(Int((summary.consumed.calories - summary.goals.calories).rounded())) kcal")
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.footnote)
            .foregroundStyle(Color.alert)
            .monospacedDigit()
        } else {
            Label {
                Text("Il te reste \(Int(summary.remainingCalories.rounded())) kcal")
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "flame.fill")
            }
            .font(.footnote)
            .foregroundStyle(.primary)
            .monospacedDigit()
        }
    }
}

#Preview("Dans l'objectif") {
    List {
        Section {
            DailySummaryCard(
                summary: DailyNutritionSummary(
                    date: .now,
                    consumed: NutritionFacts(calories: 1420, proteins: 88, carbohydrates: 150, fats: 48),
                    goals: .default,
                    entryCount: 5
                ),
                activeEnergyBurned: 620
            )
        }
    }
    .listStyle(.insetGrouped)
}

#Preview("Objectif dépassé") {
    List {
        Section {
            DailySummaryCard(
                summary: DailyNutritionSummary(
                    date: .now,
                    consumed: NutritionFacts(calories: 2610, proteins: 190, carbohydrates: 260, fats: 95),
                    goals: .default,
                    entryCount: 9
                ),
                activeEnergyBurned: nil
            )
        }
    }
    .listStyle(.insetGrouped)
}
