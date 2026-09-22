import SwiftUI

extension Macro {
    var tint: Color {
        switch self {
        case .proteins: return .blue
        case .carbohydrates: return .orange
        case .fats: return .purple
        }
    }

}

/// Compact "P 24 g · G 40 g · L 12 g" line used in every list row.
struct MacroSummaryLine: View {
    let facts: NutritionFacts
    var showsCalories: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if showsCalories {
                Text(QuantityFormatter.calories(facts.calories))
                    .fontWeight(.semibold)
                Text("·")
                    .foregroundStyle(.tertiary)
            }
            ForEach(Macro.allCases) { macro in
                HStack(spacing: 2) {
                    Text(macro.shortName)
                        .foregroundStyle(macro.tint)
                        .fontWeight(.semibold)
                    Text(QuantityFormatter.grams(macro.grams(in: facts)))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let macros = Macro.allCases
            .map { "\($0.localizedName) \(QuantityFormatter.grams($0.grams(in: facts)))" }
            .joined(separator: ", ")
        return showsCalories ? "\(QuantityFormatter.calories(facts.calories)), \(macros)" : macros
    }
}

/// Progress bar for one macro against its daily target.
struct MacroProgressBar: View {
    let macro: Macro
    let consumed: Double
    let target: Double

    private var progress: Double {
        NutritionCalculator.progress(consumed: consumed, goal: target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(macro.localizedName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(QuantityFormatter.string(from: consumed)) / \(QuantityFormatter.grams(target))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(consumed > target ? .orange : .secondary)
            }
            ProgressView(value: progress)
                .tint(macro.tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(macro.localizedName) : \(QuantityFormatter.grams(consumed)) sur \(QuantityFormatter.grams(target))")
    }
}

/// Stacked bar showing how the day's calories split across the three macros.
struct MacroDistributionBar: View {
    let facts: NutritionFacts

    private var distribution: [Macro: Double] {
        NutritionCalculator.macroDistribution(in: facts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Macro.allCases) { macro in
                        Rectangle()
                            .fill(macro.tint)
                            .frame(width: geometry.size.width * (distribution[macro] ?? 0))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .background(Capsule().fill(Color.secondary.opacity(0.15)))

            HStack(spacing: 12) {
                ForEach(Macro.allCases) { macro in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(macro.tint)
                            .frame(width: 8, height: 8)
                        Text("\(macro.localizedName) \(QuantityFormatter.percentage(distribution[macro] ?? 0))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Répartition des calories : " + Macro.allCases
            .map { "\($0.localizedName) \(QuantityFormatter.percentage(distribution[$0] ?? 0))" }
            .joined(separator: ", "))
    }
}

/// Circular calorie gauge shown at the top of the journal.
struct CalorieRing: View {
    let consumed: Double
    let goal: Double
    var lineWidth: CGFloat = 12

    private var progress: Double {
        NutritionCalculator.progress(consumed: consumed, goal: goal)
    }

    private var isOver: Bool { consumed > goal && goal > 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOver ? Color.orange : Color.accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: progress)

            VStack(spacing: 2) {
                Text("\(Int(consumed.rounded()))")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("/ \(Int(goal.rounded())) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(consumed.rounded())) calories sur \(Int(goal.rounded()))")
    }
}
