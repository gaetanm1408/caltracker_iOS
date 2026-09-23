import SwiftData
import SwiftUI

/// Compose un planning de repas sur plusieurs jours, puis en déduit la liste
/// de courses.
struct MealPlannerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MealPlannerViewModel

    init(recipes: [Recipe]) {
        _viewModel = State(initialValue: MealPlannerViewModel(recipes: recipes))
    }

    var body: some View {
        Form {
            Section("Sur combien de temps") {
                Stepper("\(viewModel.request.days) jours", value: $viewModel.request.days, in: 1...14)
                Stepper(
                    "\(viewModel.request.mealsPerDay) repas par jour",
                    value: $viewModel.request.mealsPerDay,
                    in: 0...4
                )
                Stepper(
                    "\(viewModel.request.snacksPerDay) collation(s) par jour",
                    value: $viewModel.request.snacksPerDay,
                    in: 0...3
                )
                Stepper(
                    "\(viewModel.request.servingsPerSlot) portion(s) par repas",
                    value: $viewModel.request.servingsPerSlot,
                    in: 1...6
                )
            }

            Section("Ce que je veux dans l'assiette") {
                Picker("Calories", selection: $viewModel.request.criteria.calorieBand) {
                    ForEach(CalorieBand.allCases) { band in
                        if let detail = band.detail {
                            Text("\(band.localizedName) — \(detail)").tag(band)
                        } else {
                            Text(band.localizedName).tag(band)
                        }
                    }
                }
                Picker("Protéines", selection: $viewModel.request.criteria.proteinFloor) {
                    ForEach(ProteinFloor.allCases) { floor in
                        Text(floor.localizedName).tag(floor)
                    }
                }
            }

            Section {
                ForEach(CookingEquipment.allCases.filter { !$0.isAlwaysAvailable }) { equipment in
                    Toggle(isOn: equipmentBinding(equipment)) {
                        Label(equipment.localizedName, systemImage: equipment.systemImageName)
                    }
                }
            } header: {
                Text("Mon matériel")
            } footer: {
                Text("Les recettes sans cuisson restent proposées quoi qu'il arrive.")
            }

            Section {
                NavigationLink {
                    ExcludedIngredientsView(
                        ingredients: viewModel.selectableIngredients,
                        excluded: $viewModel.request.criteria.excludedIngredients
                    )
                } label: {
                    LabeledContent("Aliments que je ne veux pas") {
                        Text(excludedSummary)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("\(viewModel.eligibleMeals.count) repas et \(viewModel.eligibleSnacks.count) collations passent tes critères.")
            }

            Section {
                Button {
                    // Recomposer à l'identique n'aurait aucun intérêt : une
                    // nouvelle graine donne une autre combinaison.
                    if viewModel.plan == nil {
                        viewModel.compose()
                    } else {
                        viewModel.reshuffle()
                    }
                } label: {
                    Label(
                        viewModel.plan == nil ? "Composer le menu" : "Proposer autre chose",
                        systemImage: viewModel.plan == nil ? "wand.and.stars" : "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(!viewModel.canCompose)
            } footer: {
                if let blocking = viewModel.blockingMessage {
                    Text(blocking).foregroundStyle(.orange)
                }
            }

            if let plan = viewModel.plan, !plan.isEmpty {
                planSection(plan)
                preparationSection
                optionsSection
                previewSection
            }
        }
        .navigationTitle("Assistant menus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Générer la liste") {
                    if viewModel.generate(using: ShoppingListService(context: context)) {
                        dismiss()
                    }
                }
                .disabled(viewModel.plan == nil)
            }
        }
    }

    private func equipmentBinding(_ equipment: CookingEquipment) -> Binding<Bool> {
        Binding(
            get: { viewModel.request.criteria.availableEquipment.contains(equipment) },
            set: { isOn in
                if isOn {
                    viewModel.request.criteria.availableEquipment.insert(equipment)
                } else {
                    viewModel.request.criteria.availableEquipment.remove(equipment)
                }
            }
        )
    }

    private var excludedSummary: String {
        let count = viewModel.request.criteria.excludedIngredients.count
        return count == 0 ? "Aucun" : "\(count) écarté(s)"
    }

    private func planSection(_ plan: MealPlan) -> some View {
        Section("Le menu") {
            ForEach(plan.days, id: \.self) { day in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Jour \(day)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(plan.slots(onDay: day)) { slot in
                        Label {
                            Text(slot.recipeName).font(.subheadline)
                        } icon: {
                            Image(systemName: slot.category.systemImageName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var preparationSection: some View {
        Section {
            ForEach(viewModel.preparations) { preparation in
                LabeledContent(preparation.name) {
                    Text("\(preparation.servings) portions")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("À cuisiner")
        } footer: {
            Text("Chaque plat est préparé en une fois : ses portions couvrent plusieurs repas.")
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Toggle("Inclure les produits de placard", isOn: $viewModel.includePantryStaples)
            Picker("Liste existante", selection: $viewModel.mode) {
                Text("Remplacer").tag(ShoppingListService.GenerationMode.replace)
                Text("Compléter").tag(ShoppingListService.GenerationMode.merge)
            }
        }
    }

    private var previewSection: some View {
        Section {
            ForEach(viewModel.previewItems) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text(item.quantityDescription)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Liste de courses (\(viewModel.previewItems.count) articles)")
        } footer: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
    }
}

/// Choix des aliments à ne pas voir proposer, pris dans les ingrédients des
/// recettes existantes.
private struct ExcludedIngredientsView: View {
    let ingredients: [String]
    @Binding var excluded: Set<String>

    @State private var search = ""

    private var visible: [String] {
        guard !search.isEmpty else { return ingredients }
        return ingredients.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            if ingredients.isEmpty {
                ContentUnavailableView(
                    "Aucun ingrédient",
                    systemImage: "carrot",
                    description: Text("Les aliments proposés ici viennent de tes recettes.")
                )
            } else {
                ForEach(visible, id: \.self) { ingredient in
                    let key = ShoppingListBuilder.normalize(ingredient)
                    Button {
                        if excluded.contains(key) {
                            excluded.remove(key)
                        } else {
                            excluded.insert(key)
                        }
                    } label: {
                        HStack {
                            Text(ingredient)
                                .foregroundStyle(excluded.contains(key) ? .secondary : .primary)
                                .strikethrough(excluded.contains(key))
                            Spacer()
                            if excluded.contains(key) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .searchable(text: $search, prompt: "Chercher un aliment")
        .navigationTitle("Aliments écartés")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !excluded.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Réinitialiser") { excluded.removeAll() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MealPlannerView(recipes: [])
    }
    .modelContainer(PreviewData.container())
}
