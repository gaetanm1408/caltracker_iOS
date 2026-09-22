import Foundation

/// One ingredient needed by one recipe, already scaled to the number of
/// servings the user wants to cook.
struct IngredientRequirement: Hashable, Sendable {
    let name: String
    let quantity: Double
    let unit: MeasurementUnit
    let isPantryStaple: Bool
    let recipeName: String

    init(
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        isPantryStaple: Bool = false,
        recipeName: String = ""
    ) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.isPantryStaple = isPantryStaple
        self.recipeName = recipeName
    }
}

/// A merged line ready to be written to the shopping list.
struct ShoppingListDraftItem: Identifiable, Hashable, Sendable {
    let name: String
    let quantity: Double
    let unit: MeasurementUnit
    let sourceRecipeNames: [String]

    var id: String { ShoppingListBuilder.mergeKey(name: name, unit: unit) }

    var quantityDescription: String {
        "\(QuantityFormatter.string(from: quantity)) \(unit.displayName)"
    }
}

/// How many servings of a recipe to cook.
struct RecipeSelection: Hashable, Sendable {
    let recipeID: UUID
    let recipeName: String
    let baseServings: Int
    let desiredServings: Int
    let ingredients: [IngredientRequirement]

    /// Factor applied to every ingredient quantity.
    var scaleFactor: Double {
        guard baseServings > 0 else { return 1 }
        return Double(desiredServings) / Double(baseServings)
    }
}

/// Turns a set of selected recipes into a de-duplicated shopping list.
///
/// Quantities are merged only when the ingredient names match after
/// normalisation *and* their units share a dimension — 200 g of tomatoes and
/// 3 tomatoes stay on two separate lines because they cannot be added up.
enum ShoppingListBuilder {
    static func build(
        from selections: [RecipeSelection],
        includingPantryStaples: Bool = true
    ) -> [ShoppingListDraftItem] {
        let requirements = selections.flatMap { selection in
            selection.ingredients.map { ingredient in
                IngredientRequirement(
                    name: ingredient.name,
                    quantity: ingredient.quantity * selection.scaleFactor,
                    unit: ingredient.unit,
                    isPantryStaple: ingredient.isPantryStaple,
                    recipeName: selection.recipeName
                )
            }
        }
        return merge(requirements, includingPantryStaples: includingPantryStaples)
    }

    static func merge(
        _ requirements: [IngredientRequirement],
        includingPantryStaples: Bool = true
    ) -> [ShoppingListDraftItem] {
        var order: [String] = []
        var accumulator: [String: Accumulated] = [:]

        for requirement in requirements {
            guard includingPantryStaples || !requirement.isPantryStaple else { continue }
            let trimmedName = requirement.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty, requirement.quantity > 0 else { continue }

            let key = mergeKey(name: trimmedName, unit: requirement.unit)
            let baseQuantity = requirement.quantity * requirement.unit.baseUnitFactor

            if var existing = accumulator[key] {
                existing.baseQuantity += baseQuantity
                if !requirement.recipeName.isEmpty, !existing.recipeNames.contains(requirement.recipeName) {
                    existing.recipeNames.append(requirement.recipeName)
                }
                accumulator[key] = existing
            } else {
                order.append(key)
                accumulator[key] = Accumulated(
                    displayName: trimmedName,
                    baseQuantity: baseQuantity,
                    dimension: requirement.unit.dimension,
                    recipeNames: requirement.recipeName.isEmpty ? [] : [requirement.recipeName]
                )
            }
        }

        return order.compactMap { key in
            guard let accumulated = accumulator[key] else { return nil }
            let unit = MeasurementUnit.preferredUnit(
                forBaseQuantity: accumulated.baseQuantity,
                dimension: accumulated.dimension
            )
            let quantity = accumulated.baseQuantity / unit.baseUnitFactor
            return ShoppingListDraftItem(
                name: accumulated.displayName,
                quantity: (quantity * 100).rounded() / 100,
                unit: unit,
                sourceRecipeNames: accumulated.recipeNames
            )
        }
    }

    /// Ingredients only merge when this key matches: same normalised name and
    /// same physical dimension.
    static func mergeKey(name: String, unit: MeasurementUnit) -> String {
        "\(normalize(name))|\(unit.dimension.rawValue)"
    }

    /// Case- and accent-insensitive, so "Échalote", "echalote" and "Echalotes"
    /// land on the same row.
    static func normalize(_ name: String) -> String {
        let folded = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        let singular = folded.hasSuffix("s") && folded.count > 3 ? String(folded.dropLast()) : folded
        return singular.trimmingCharacters(in: .whitespaces)
    }

    private struct Accumulated {
        let displayName: String
        var baseQuantity: Double
        let dimension: MeasurementUnit.Dimension
        var recipeNames: [String]
    }
}

extension RecipeSelection {
    /// Builds a selection from a persisted recipe.
    init(recipe: Recipe, desiredServings: Int? = nil) {
        self.init(
            recipeID: recipe.id,
            recipeName: recipe.name,
            baseServings: max(1, recipe.servings),
            desiredServings: max(1, desiredServings ?? recipe.servings),
            ingredients: recipe.ingredients
                .sorted { $0.sortIndex < $1.sortIndex }
                .map {
                    IngredientRequirement(
                        name: $0.name,
                        quantity: $0.quantity,
                        unit: $0.unit,
                        isPantryStaple: $0.isPantryStaple,
                        recipeName: recipe.name
                    )
                }
        )
    }
}
