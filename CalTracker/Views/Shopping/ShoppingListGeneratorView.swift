import SwiftData
import SwiftUI

/// Picks recipes and servings, previews the merged list, then writes it.
struct ShoppingListGeneratorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ShoppingListGeneratorViewModel

    init(recipes: [Recipe], preselected: Set<UUID> = []) {
        _viewModel = State(
            initialValue: ShoppingListGeneratorViewModel(recipes: recipes, preselected: preselected)
        )
    }

    var body: some View {
        Form {
            Section {
                ForEach(viewModel.choices) { choice in
                    RecipeChoiceRow(
                        choice: choice,
                        onToggle: { viewModel.toggle(choice) },
                        onServingsChange: { viewModel.setServings($0, for: choice) }
                    )
                }
            } header: {
                HStack {
                    Text("Recettes")
                    Spacer()
                    Button(viewModel.hasSelection ? "Tout désélectionner" : "Tout sélectionner") {
                        if viewModel.hasSelection {
                            viewModel.deselectAll()
                        } else {
                            viewModel.selectAll()
                        }
                    }
                    .font(.caption)
                    .textCase(nil)
                }
            }

            Section("Options") {
                Toggle("Inclure les produits de placard", isOn: $viewModel.includePantryStaples)
                Picker("Liste existante", selection: $viewModel.mode) {
                    Text("Remplacer").tag(ShoppingListService.GenerationMode.replace)
                    Text("Compléter").tag(ShoppingListService.GenerationMode.merge)
                }
            }

            Section {
                if viewModel.preview.isEmpty {
                    Text("Sélectionne des recettes pour voir la liste.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.preview) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text(item.quantityDescription)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            if item.sourceRecipeNames.count > 1 {
                                Text("Regroupé depuis \(item.sourceRecipeNames.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text("Aperçu (\(viewModel.preview.count) articles)")
            } footer: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(Color.alert)
                }
            }
        }
        .navigationTitle("Générer la liste")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Générer") {
                    if viewModel.generate(using: ShoppingListService(context: context)) {
                        dismiss()
                    }
                }
                .disabled(!viewModel.hasSelection)
            }
        }
    }
}

private struct RecipeChoiceRow: View {
    let choice: ShoppingListGeneratorViewModel.RecipeChoice
    let onToggle: () -> Void
    let onServingsChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: choice.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(choice.isSelected ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(choice.recipe.name)
                            .foregroundStyle(.primary)
                        Text("\(choice.recipe.ingredients.count) ingrédients")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if choice.isSelected {
                Stepper(
                    "Portions à préparer : \(choice.servings)",
                    value: Binding(
                        get: { choice.servings },
                        set: { onServingsChange($0) }
                    ),
                    in: 1...20
                )
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ShoppingListGeneratorView(recipes: [])
    }
    .modelContainer(PreviewData.container())
}
