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

            RecipeCriteriaSections(
                criteria: $viewModel.request.criteria,
                ingredientGroups: viewModel.ingredientGroups,
                matchSummary: "\(viewModel.eligibleMeals.count) repas et "
                    + "\(viewModel.eligibleSnacks.count) collations passent tes critères."
            )

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
                    Text(blocking).foregroundStyle(Color.alert)
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
                Text(errorMessage).foregroundStyle(Color.alert)
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
