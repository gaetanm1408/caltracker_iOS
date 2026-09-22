import SwiftUI

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.productNameSnapshot)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(QuantityFormatter.grams(entry.quantityInGrams))
                    if let brand = entry.brandSnapshot, !brand.isEmpty {
                        Text("·")
                        Text(brand)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                MacroSummaryLine(facts: entry.consumedNutrition, showsCalories: false)
            }

            Spacer(minLength: 8)

            Text(QuantityFormatter.calories(entry.consumedNutrition.calories))
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}
