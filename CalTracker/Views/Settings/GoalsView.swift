import SwiftData
import SwiftUI

/// Profil corporel, objectif de poids et cible calorique — calculée depuis le
/// profil ou saisie à la main.
struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var usesCalculatedGoal = false
    @State private var sex: BiologicalSex = .female
    @State private var ageText = ""
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var weightGoal: WeightGoal = .maintenance

    @State private var calorieText = "2000"
    @State private var proteinPercent: Double = 30
    @State private var carbPercent: Double = 40
    @State private var fatPercent: Double = 30

    private var measurements: BodyMeasurements {
        BodyMeasurements(
            weightInKilograms: Double.parseUserInput(weightText) ?? 0,
            heightInCentimeters: Double.parseUserInput(heightText) ?? 0,
            age: Int(Double.parseUserInput(ageText) ?? 0),
            sex: sex
        )
    }

    private var manualCalories: Double {
        Double.parseUserInput(calorieText) ?? 0
    }

    private var manualTotalPercent: Double {
        proteinPercent + carbPercent + fatPercent
    }

    private var isManualSplitBalanced: Bool {
        abs(manualTotalPercent - 100) < 0.5
    }

    /// Objectifs tels qu'ils seront enregistrés.
    private var previewGoals: NutritionGoals {
        guard usesCalculatedGoal, measurements.isComplete else {
            return NutritionGoals(
                calories: manualCalories,
                proteinPercentage: proteinPercent / 100,
                carbohydratePercentage: carbPercent / 100,
                fatPercentage: fatPercent / 100
            )
        }
        return EnergyCalculator.goals(
            for: measurements,
            activity: activityLevel,
            goal: weightGoal
        )
    }

    private var canSave: Bool {
        if usesCalculatedGoal { return measurements.isComplete }
        return isManualSplitBalanced && manualCalories > 0
    }

    var body: some View {
        Form {
            Section {
                Toggle("Calculer depuis mon profil", isOn: $usesCalculatedGoal)
            } footer: {
                Text("Estime ta dépense quotidienne à partir de tes mesures, puis en déduit ta cible selon l'objectif choisi.")
            }

            if usesCalculatedGoal {
                profileSection
                goalSection
                calculationSection
            } else {
                manualSection
            }

            Section("Cibles par macro") {
                ForEach(Macro.allCases) { macro in
                    LabeledContent(macro.localizedName) {
                        Text(QuantityFormatter.grams(previewGoals.targetGrams(for: macro)))
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("Profil et objectifs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer", action: save)
                    .disabled(!canSave)
            }
        }
        .onAppear(perform: loadProfile)
    }

    private var profileSection: some View {
        Section("Mon profil") {
            Picker("Sexe", selection: $sex) {
                ForEach(BiologicalSex.allCases) { sex in
                    Text(sex.localizedName).tag(sex)
                }
            }
            .pickerStyle(.segmented)

            measurementField("Âge", text: $ageText, unit: "ans")
            measurementField("Taille", text: $heightText, unit: "cm")
            measurementField("Poids", text: $weightText, unit: "kg")

            Picker("Activité", selection: $activityLevel) {
                ForEach(ActivityLevel.allCases) { level in
                    Text(level.localizedName).tag(level)
                }
            }
            Text(activityLevel.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var goalSection: some View {
        Section("Objectif") {
            Picker("Objectif", selection: $weightGoal) {
                ForEach(WeightGoal.allCases) { goal in
                    Text(goal.localizedName).tag(goal)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(weightGoal.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var calculationSection: some View {
        if measurements.isComplete {
            Section {
                LabeledContent("Métabolisme de base") {
                    Text(QuantityFormatter.calories(EnergyCalculator.basalMetabolicRate(for: measurements)))
                        .monospacedDigit()
                }
                LabeledContent("Dépense quotidienne") {
                    Text(QuantityFormatter.calories(
                        EnergyCalculator.totalDailyEnergyExpenditure(for: measurements, activity: activityLevel)
                    ))
                    .monospacedDigit()
                }
                LabeledContent("Cible") {
                    Text(QuantityFormatter.calories(previewGoals.calories))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            } header: {
                Text("Calcul")
            } footer: {
                Text("Métabolisme de base estimé par l'équation de Mifflin-St Jeor, puis multiplié par ton niveau d'activité.")
            }
        } else {
            Section {
                Label("Complète ton âge, ta taille et ton poids pour obtenir une cible.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var manualSection: some View {
        Group {
            Section("Objectif quotidien") {
                HStack {
                    Text("Calories")
                    Spacer()
                    TextField("2000", text: $calorieText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text("kcal").foregroundStyle(.secondary)
                }
            }

            Section {
                macroSlider(for: .proteins, value: $proteinPercent)
                macroSlider(for: .carbohydrates, value: $carbPercent)
                macroSlider(for: .fats, value: $fatPercent)
            } header: {
                Text("Répartition des macros")
            } footer: {
                if isManualSplitBalanced {
                    Text("Total : 100 %")
                } else {
                    Text("Le total doit faire 100 % (actuellement \(Int(manualTotalPercent.rounded())) %).")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func measurementField(_ label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
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

    private func loadProfile() {
        guard let profile = profiles.first else { return }
        usesCalculatedGoal = profile.usesCalculatedGoal
        sex = profile.sex
        activityLevel = profile.activityLevel
        weightGoal = profile.weightGoal
        if profile.age > 0 { ageText = String(profile.age) }
        if profile.heightInCentimeters > 0 {
            heightText = QuantityFormatter.string(from: profile.heightInCentimeters)
        }
        if profile.weightInKilograms > 0 {
            weightText = QuantityFormatter.string(from: profile.weightInKilograms)
        }
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

        profile.usesCalculatedGoal = usesCalculatedGoal
        profile.measurements = measurements
        profile.activityLevel = activityLevel
        profile.weightGoal = weightGoal
        // Les valeurs manuelles sont conservées même en mode calculé, pour que
        // basculer l'interrupteur dans un sens puis dans l'autre ne les perde pas.
        profile.dailyCalorieGoal = manualCalories
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
