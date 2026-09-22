import Foundation
import Testing

@testable import CalTracker

@Suite("Génération de la liste de courses")
struct ShoppingListBuilderTests {
    @Test("Les mêmes ingrédients sont fusionnés en une seule ligne")
    func mergesIdenticalIngredients() {
        let items = ShoppingListBuilder.merge([
            IngredientRequirement(name: "Tomates cerises", quantity: 200, unit: .gram, recipeName: "Bowl"),
            IngredientRequirement(name: "Tomates cerises", quantity: 150, unit: .gram, recipeName: "Salade")
        ])

        #expect(items.count == 1)
        #expect(items[0].quantity == 350)
        #expect(items[0].unit == .gram)
        #expect(items[0].sourceRecipeNames == ["Bowl", "Salade"])
    }

    @Test("Les unités d'une même dimension sont converties avant addition")
    func convertsUnitsBeforeMerging() {
        let items = ShoppingListBuilder.merge([
            IngredientRequirement(name: "Farine", quantity: 500, unit: .gram),
            IngredientRequirement(name: "Farine", quantity: 1, unit: .kilogram)
        ])

        #expect(items.count == 1)
        // 1500 g devient 1,5 kg pour rester lisible en rayon.
        #expect(items[0].unit == .kilogram)
        #expect(items[0].quantity == 1.5)
    }

    @Test("Les dimensions incompatibles restent sur des lignes distinctes")
    func keepsIncompatibleDimensionsApart() {
        let items = ShoppingListBuilder.merge([
            IngredientRequirement(name: "Tomates", quantity: 200, unit: .gram),
            IngredientRequirement(name: "Tomates", quantity: 3, unit: .piece)
        ])

        #expect(items.count == 2)
        #expect(items.contains { $0.unit == .gram && $0.quantity == 200 })
        #expect(items.contains { $0.unit == .piece && $0.quantity == 3 })
    }

    @Test("Accents, casse et pluriels ne créent pas de doublons")
    func normalizesNames() {
        let items = ShoppingListBuilder.merge([
            IngredientRequirement(name: "Échalotes", quantity: 2, unit: .piece),
            IngredientRequirement(name: "echalote", quantity: 1, unit: .piece),
            IngredientRequirement(name: "  ÉCHALOTE  ", quantity: 3, unit: .piece)
        ])

        #expect(items.count == 1)
        #expect(items[0].quantity == 6)
        // Le premier libellé rencontré est conservé pour l'affichage.
        #expect(items[0].name == "Échalotes")
    }

    @Test("Les cuillères sont converties en millilitres")
    func mergesVolumeUnits() {
        let items = ShoppingListBuilder.merge([
            IngredientRequirement(name: "Huile d'olive", quantity: 2, unit: .tablespoon),
            IngredientRequirement(name: "Huile d'olive", quantity: 2, unit: .teaspoon)
        ])

        #expect(items.count == 1)
        #expect(items[0].unit == .milliliter)
        #expect(items[0].quantity == 40) // 2 * 15 + 2 * 5
    }

    @Test("Les quantités suivent le nombre de portions demandé")
    func scalesWithServings() {
        let selection = RecipeSelection(
            recipeID: UUID(),
            recipeName: "Bowl",
            baseServings: 2,
            desiredServings: 6,
            ingredients: [
                IngredientRequirement(name: "Quinoa", quantity: 150, unit: .gram)
            ]
        )

        let items = ShoppingListBuilder.build(from: [selection])

        #expect(items.count == 1)
        #expect(items[0].quantity == 450)
    }

    @Test("Deux recettes mises à l'échelle s'additionnent")
    func combinesScaledRecipes() {
        let bowl = RecipeSelection(
            recipeID: UUID(),
            recipeName: "Bowl",
            baseServings: 2,
            desiredServings: 4,
            ingredients: [IngredientRequirement(name: "Tomates cerises", quantity: 200, unit: .gram)]
        )
        let salad = RecipeSelection(
            recipeID: UUID(),
            recipeName: "Salade",
            baseServings: 4,
            desiredServings: 2,
            ingredients: [IngredientRequirement(name: "Tomates cerises", quantity: 150, unit: .gram)]
        )

        let items = ShoppingListBuilder.build(from: [bowl, salad])

        #expect(items.count == 1)
        #expect(items[0].quantity == 475) // 400 + 75
        #expect(items[0].sourceRecipeNames.count == 2)
    }

    @Test("Les produits de placard peuvent être exclus")
    func canExcludePantryStaples() {
        let requirements = [
            IngredientRequirement(name: "Lentilles", quantity: 250, unit: .gram),
            IngredientRequirement(name: "Huile d'olive", quantity: 3, unit: .tablespoon, isPantryStaple: true)
        ]

        #expect(ShoppingListBuilder.merge(requirements).count == 2)

        let filtered = ShoppingListBuilder.merge(requirements, includingPantryStaples: false)
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "Lentilles")
    }

    @Test("Les lignes vides ou sans quantité sont ignorées")
    func skipsEmptyRequirements() {
        let items = ShoppingListBuilder.merge([
            IngredientRequirement(name: "   ", quantity: 100, unit: .gram),
            IngredientRequirement(name: "Sel", quantity: 0, unit: .gram),
            IngredientRequirement(name: "Riz", quantity: 200, unit: .gram)
        ])

        #expect(items.count == 1)
        #expect(items[0].name == "Riz")
    }

    @Test("L'ordre de première apparition est conservé")
    func preservesInsertionOrder() {
        let items = ShoppingListBuilder.merge([
            IngredientRequirement(name: "Poulet", quantity: 300, unit: .gram),
            IngredientRequirement(name: "Quinoa", quantity: 150, unit: .gram),
            IngredientRequirement(name: "Poulet", quantity: 100, unit: .gram)
        ])

        #expect(items.map(\.name) == ["Poulet", "Quinoa"])
        #expect(items[0].quantity == 400)
    }
}
