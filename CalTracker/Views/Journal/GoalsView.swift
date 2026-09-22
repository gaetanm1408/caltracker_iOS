import SwiftData
import SwiftUI

/// Daily calorie target and macro split.
struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var calorieText = "2000"
    @State private var proteinPercent: Double = 30
    @State private var carbPercent: Double = 40
    @State private var fatPercent: Double = 30

    private var calories: Double {
        Double.parseUserInput(calorieText) ?? 0
    }

    private var totalPercent: Double {
        proteinPercent + carbPercent + fatPercent
    }

    private var isBalanced: Bool {
        abs(totalPercent - 100) < 0.5
    }

    private var previewGoals: NutritionGoals {
        NutritionGoals(
            calories: calories,
            proteinPercentage: proteinPercent / 100,
            carbohydratePercentage: carbPercent / 100,
            fatPercentage: fatPercent / 100
        )
    }

    var body: some View {
        Form {
            Section("Objectif quotidien") {
                HStack {
                    Text("Calories")
                    Spacer()
                    TextField("2000", text: $calorieText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text("kcal")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                macroSlider(for: .proteins, value: $proteinPercent)
                macroSlider(for: .carbohydrates, value: $carbPercent)
                macroSlider(for: .fats, value: $fatPercent)
            } header: {
                Text("Répartition des macros")
            } footer: {
                if isBalanced {
                    Text("Total : 100 %")
                } else {
                    Text("Le total doit faire 100 % (actuellement \(Int(totalPercent.rounded())) %).")
                        .foregroundStyle(.orange)
                }
            }

            Section("Cibles calculées") {
                ForEach(Macro.allCases) { macro in
                    LabeledContent(macro.localizedName) {
                        Text(QuantityFormatter.grams(previewGoals.targetGrams(for: macro)))
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("Objectifs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer", action: save)
                    .disabled(!isBalanced || calories <= 0)
            }
        }
        .onAppear(perform: loadCurrentGoals)
    }

    private func macroSlider(for macro: Macro, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label {
                    Text(macro.localizedName)
                } icon: {
                    Circle().fill(macro.tint).frame(width: 10, height: 10)
                }
                Spacer()
                Text("\(Int(value.wrappedValue.rounded())) %")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...80, step: 5)
                .tint(macro.tint)
        }
    }

    private func loadCurrentGoals() {
        guard let profile = profiles.first else { return }
        calorieText = String(Int(profile.dailyCalorieGoal.rounded()))
        proteinPercent = (profile.proteinPercentage * 100).rounded()
        carbPercent = (profile.carbohydratePercentage * 100).rounded()
        fatPercent = (profile.fatPercentage * 100).rounded()
    }

    private func save() {
        let profile = profiles.first ?? {
            let created = UserProfile()
            context.insert(created)
            return created
        }()
        profile.dailyCalorieGoal = calories
        profile.proteinPercentage = proteinPercent / 100
        profile.carbohydratePercentage = carbPercent / 100
        profile.fatPercentage = fatPercent / 100
        profile.updatedAt = .now
        dismiss()
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
    .modelContainer(PreviewData.container())
}
