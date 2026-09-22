import Foundation
import SwiftData

/// Persists the shopping list and applies the drafts produced by
/// `ShoppingListBuilder`.
struct ShoppingListService {
    enum GenerationMode {
        /// Wipes the current list before writing the new one.
        case replace
        /// Adds to the existing list, summing quantities of rows that match.
        case merge
    }

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func allItems() throws -> [ShoppingListItem] {
        try context.fetch(
            FetchDescriptor<ShoppingListItem>(sortBy: [SortDescriptor(\.sortIndex)])
        )
    }

    /// Generates the list from the selected recipes.
    @discardableResult
    func generate(
        from selections: [RecipeSelection],
        mode: GenerationMode = .replace,
        includingPantryStaples: Bool = true
    ) throws -> [ShoppingListItem] {
        let drafts = ShoppingListBuilder.build(
            from: selections,
            includingPantryStaples: includingPantryStaples
        )

        var existing = try allItems()
        if mode == .replace {
            // Manually added rows are the user's own input; generated ones are
            // derived data and can be rebuilt.
            for item in existing where !item.isManuallyAdded {
                context.delete(item)
            }
            existing = existing.filter(\.isManuallyAdded)
        }

        var byKey = Dictionary(
            existing.map { (ShoppingListBuilder.mergeKey(name: $0.name, unit: $0.unit), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
        var result: [ShoppingListItem] = []

        for draft in drafts {
            let key = ShoppingListBuilder.mergeKey(name: draft.name, unit: draft.unit)
            if let item = byKey[key] {
                let merged = ShoppingListBuilder.merge([
                    IngredientRequirement(name: item.name, quantity: item.quantity, unit: item.unit),
                    IngredientRequirement(name: draft.name, quantity: draft.quantity, unit: draft.unit)
                ])
                if let combined = merged.first {
                    item.quantity = combined.quantity
                    item.unit = combined.unit
                }
                item.sourceRecipeNames = Array(Set(item.sourceRecipeNames + draft.sourceRecipeNames)).sorted()
                item.isChecked = false
                result.append(item)
            } else {
                let item = ShoppingListItem(
                    name: draft.name,
                    quantity: draft.quantity,
                    unit: draft.unit,
                    sortIndex: nextIndex,
                    sourceRecipeNames: draft.sourceRecipeNames
                )
                context.insert(item)
                byKey[key] = item
                nextIndex += 1
                result.append(item)
            }
        }
        return result
    }

    @discardableResult
    func addManualItem(name: String, quantity: Double, unit: MeasurementUnit) throws -> ShoppingListItem {
        let nextIndex = (try allItems().map(\.sortIndex).max() ?? -1) + 1
        let item = ShoppingListItem(
            name: name,
            quantity: quantity,
            unit: unit,
            sortIndex: nextIndex,
            isManuallyAdded: true
        )
        context.insert(item)
        return item
    }

    func toggle(_ item: ShoppingListItem) {
        item.isChecked.toggle()
    }

    func delete(_ item: ShoppingListItem) {
        context.delete(item)
    }

    func clearChecked() throws {
        for item in try allItems() where item.isChecked {
            context.delete(item)
        }
    }

    /// Plain-text export for the share sheet.
    func shareText(for items: [ShoppingListItem]) -> String {
        let lines = items
            .filter { !$0.isChecked }
            .map { "• \($0.name) — \($0.quantityDescription)" }
        guard !lines.isEmpty else { return "Liste de courses vide" }
        return (["Liste de courses"] + lines).joined(separator: "\n")
    }
}
