import Foundation
import Observation
import SwiftData

/// State of the "generate a shopping list" sheet: which recipes are picked, for
/// how many servings, and the live preview of the resulting list.
@MainActor
@Observable
final class ShoppingListGeneratorViewModel {
    struct RecipeChoice: Identifiable {
        let recipe: Recipe
        var isSelected: Bool
        var servings: Int

        var id: UUID { recipe.id }
    }

    var choices: [RecipeChoice]
    var includePantryStaples: Bool = true
    var mode: ShoppingListService.GenerationMode = .replace
    private(set) var errorMessage: String?

    init(recipes: [Recipe], preselected: Set<UUID> = []) {
        self.choices = recipes
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map {
                RecipeChoice(
                    recipe: $0,
                    isSelected: preselected.contains($0.id),
                    servings: max(1, $0.servings)
                )
            }
    }

    var selectedChoices: [RecipeChoice] {
        choices.filter(\.isSelected)
    }

    var hasSelection: Bool { !selectedChoices.isEmpty }

    var selections: [RecipeSelection] {
        selectedChoices.map { RecipeSelection(recipe: $0.recipe, desiredServings: $0.servings) }
    }

    /// Live preview shown under the recipe picker.
    var preview: [ShoppingListDraftItem] {
        ShoppingListBuilder.build(from: selections, includingPantryStaples: includePantryStaples)
    }

    func toggle(_ choice: RecipeChoice) {
        guard let index = choices.firstIndex(where: { $0.id == choice.id }) else { return }
        choices[index].isSelected.toggle()
    }

    func setServings(_ servings: Int, for choice: RecipeChoice) {
        guard let index = choices.firstIndex(where: { $0.id == choice.id }) else { return }
        choices[index].servings = max(1, servings)
        choices[index].isSelected = true
    }

    func selectAll() {
        for index in choices.indices {
            choices[index].isSelected = true
        }
    }

    func deselectAll() {
        for index in choices.indices {
            choices[index].isSelected = false
        }
    }

    /// Writes the preview to the store. Returns `true` when the sheet can close.
    func generate(using service: ShoppingListService) -> Bool {
        guard hasSelection else {
            errorMessage = "Sélectionne au moins une recette."
            return false
        }
        do {
            try service.generate(
                from: selections,
                mode: mode,
                includingPantryStaples: includePantryStaples
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = "La liste n'a pas pu être enregistrée."
            return false
        }
    }
}
