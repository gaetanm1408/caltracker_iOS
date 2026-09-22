import SwiftData
import SwiftUI

/// Adjusts the quantity and meal of an existing journal line.
struct EditEntrySheet: View {
    let entry: FoodEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var quantityText: String = ""
    @State private var meal: MealType = .snack

    private var quantity: Double {
        Double.parseUserInput(quantityText) ?? 0
    }

    private var previewNutrition: NutritionFacts {
        NutritionCalculator.nutrition(for: entry.nutritionPer100g, quantityInGrams: quantity)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Aliment", value: entry.productNameSnapshot)
                HStack {
                    Text("Quantité")
                    Spacer()
                    TextField("0", text: $quantityText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text("g")
                        .foregroundStyle(.secondary)
                }
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.orderedCases) { meal in
                        Text(meal.localizedName).tag(meal)
                    }
                }
            }

            Section("Apports") {
                NutritionBreakdownView(facts: previewNutrition)
            }

            Section {
                Button(role: .destructive) {
                    JournalService(context: context).delete(entry)
                    dismiss()
                } label: {
                    Label("Supprimer du journal", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Modifier")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer", action: save)
                    .disabled(quantity <= 0)
            }
        }
        .onAppear {
            quantityText = QuantityFormatter.string(from: entry.quantityInGrams)
            meal = entry.meal
        }
    }

    private func save() {
        JournalService(context: context).update(entry, quantityInGrams: quantity, meal: meal)
        dismiss()
    }
}

/// Calories plus the macro rows, shared by the edit and add sheets.
struct NutritionBreakdownView: View {
    let facts: NutritionFacts

    var body: some View {
        LabeledContent("Calories") {
            Text(QuantityFormatter.calories(facts.calories))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        ForEach(Macro.allCases) { macro in
            LabeledContent {
                Text(QuantityFormatter.grams(macro.grams(in: facts)))
                    .monospacedDigit()
            } label: {
                Label {
                    Text(macro.localizedName)
                } icon: {
                    Circle()
                        .fill(macro.tint)
                        .frame(width: 10, height: 10)
                }
            }
        }
        if facts.fibers > 0 {
            LabeledContent("Fibres") {
                Text(QuantityFormatter.grams(facts.fibers))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
