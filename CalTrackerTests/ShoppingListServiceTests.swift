import Foundation
import SwiftData
import Testing

@testable import CalTracker

@MainActor
@Suite("Persistance de la liste de courses")
struct ShoppingListServiceTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let recipes: RecipeService
    private let shopping: ShoppingListService

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
        recipes = RecipeService(context: context)
        shopping = ShoppingListService(context: context)
    }

    @discardableResult
    private func makeBowl() -> Recipe {
        let recipe = recipes.create(name: "Bowl", servings: 2)
        recipes.addIngredient(to: recipe, name: "Poulet", quantity: 300, unit: .gram)
        recipes.addIngredient(to: recipe, name: "Tomates cerises", quantity: 200, unit: .gram)
        return recipe
    }

    @discardableResult
    private func makeSalad() -> Recipe {
        let recipe = recipes.create(name: "Salade", servings: 4)
        recipes.addIngredient(to: recipe, name: "Tomates cerises", quantity: 150, unit: .gram)
        recipes.addIngredient(to: recipe, name: "Huile d'olive", quantity: 3, unit: .tablespoon, isPantryStaple: true)
        return recipe
    }

    @Test("La génération écrit les ingrédients fusionnés")
    func generatesMergedList() throws {
        let bowl = makeBowl()
        let salad = makeSalad()

        try shopping.generate(from: [RecipeSelection(recipe: bowl), RecipeSelection(recipe: salad)])

        let items = try shopping.allItems()
        #expect(items.count == 3)

        let tomatoes = try #require(items.first { $0.name == "Tomates cerises" })
        #expect(tomatoes.quantity == 350)
        #expect(tomatoes.sourceRecipeNames.count == 2)
    }

    @Test("Le mode remplacement repart d'une liste propre")
    func replaceModeResetsList() throws {
        let bowl = makeBowl()
        try shopping.generate(from: [RecipeSelection(recipe: bowl)])
        #expect(try shopping.allItems().count == 2)

        let salad = makeSalad()
        try shopping.generate(from: [RecipeSelection(recipe: salad)], mode: .replace)

        let names = try shopping.allItems().map(\.name).sorted()
        #expect(names == ["Huile d'olive", "Tomates cerises"])
    }

    @Test("Le mode complément additionne les quantités existantes")
    func mergeModeAddsQuantities() throws {
        let bowl = makeBowl()
        try shopping.generate(from: [RecipeSelection(recipe: bowl)])
        try shopping.generate(from: [RecipeSelection(recipe: bowl)], mode: .merge)

        let chicken = try #require(try shopping.allItems().first { $0.name == "Poulet" })
        #expect(chicken.quantity == 600)
        #expect(try shopping.allItems().count == 2)
    }

    @Test("Les articles ajoutés à la main survivent à une régénération")
    func keepsManualItemsOnReplace() throws {
        try shopping.addManualItem(name: "Papier essuie-tout", quantity: 1, unit: .piece)
        let bowl = makeBowl()

        try shopping.generate(from: [RecipeSelection(recipe: bowl)], mode: .replace)

        let items = try shopping.allItems()
        #expect(items.contains { $0.name == "Papier essuie-tout" })
        #expect(items.count == 3)
    }

    @Test("Les produits de placard peuvent être exclus de la génération")
    func excludesPantryStaples() throws {
        let salad = makeSalad()

        try shopping.generate(
            from: [RecipeSelection(recipe: salad)],
            includingPantryStaples: false
        )

        let names = try shopping.allItems().map(\.name)
        #expect(names == ["Tomates cerises"])
    }

    @Test("Les portions demandées mettent la liste à l'échelle")
    func scalesWithDesiredServings() throws {
        let bowl = makeBowl()

        try shopping.generate(from: [RecipeSelection(recipe: bowl, desiredServings: 6)])

        let chicken = try #require(try shopping.allItems().first { $0.name == "Poulet" })
        #expect(chicken.quantity == 900)
    }

    @Test("Cocher puis vider retire les articles achetés")
    func clearsCheckedItems() throws {
        let bowl = makeBowl()
        try shopping.generate(from: [RecipeSelection(recipe: bowl)])

        let items = try shopping.allItems()
        shopping.toggle(items[0])
        #expect(items[0].isChecked)

        try shopping.clearChecked()
        #expect(try shopping.allItems().count == 1)
    }

    @Test("Le partage liste uniquement les articles restants")
    func sharesPendingItemsOnly() throws {
        let bowl = makeBowl()
        try shopping.generate(from: [RecipeSelection(recipe: bowl)])

        let items = try shopping.allItems()
        shopping.toggle(items[0])

        let text = shopping.shareText(for: items)
        #expect(text.contains(items[1].name))
        #expect(!text.contains("• \(items[0].name)"))
    }
}

@MainActor
@Suite("Recettes")
struct RecipeServiceTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let service: RecipeService

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
        service = RecipeService(context: context)
    }

    @Test("Les macros d'une recette découlent de ses ingrédients")
    func computesRecipeNutrition() throws {
        let recipe = service.create(name: "Bowl", servings: 2)
        service.addIngredient(
            to: recipe, name: "Poulet", quantity: 200, unit: .gram,
            nutritionPer100g: NutritionFacts(calories: 121, proteins: 25, carbohydrates: 0, fats: 2.3)
        )
        service.addIngredient(
            to: recipe, name: "Quinoa", quantity: 100, unit: .gram,
            nutritionPer100g: NutritionFacts(calories: 368, proteins: 14, carbohydrates: 57, fats: 6)
        )

        #expect(recipe.hasNutritionData)
        #expect(abs(recipe.totalNutrition.calories - (242 + 368)) < 0.01)
        #expect(abs(recipe.nutritionPerServing.calories - 305) < 0.01)
        #expect(abs(recipe.nutritionPerServing.proteins - 32) < 0.01)
    }

    @Test("Un ingrédient compté à la pièce n'apporte pas de macros")
    func ignoresCountableIngredients() throws {
        let recipe = service.create(name: "Salade", servings: 1)
        service.addIngredient(
            to: recipe, name: "Œuf", quantity: 2, unit: .piece,
            nutritionPer100g: NutritionFacts(calories: 143, proteins: 13, carbohydrates: 0, fats: 10)
        )

        #expect(recipe.totalNutrition == .zero)
    }

    @Test("Les ingrédients conservent leur ordre d'ajout")
    func keepsIngredientOrder() throws {
        let recipe = service.create(name: "Bowl")
        service.addIngredient(to: recipe, name: "A", quantity: 1, unit: .gram)
        service.addIngredient(to: recipe, name: "B", quantity: 1, unit: .gram)
        service.addIngredient(to: recipe, name: "C", quantity: 1, unit: .gram)

        let names = recipe.ingredients.sorted { $0.sortIndex < $1.sortIndex }.map(\.name)
        #expect(names == ["A", "B", "C"])
    }

    @Test("Dupliquer une recette copie ses ingrédients")
    func duplicatesRecipe() throws {
        let recipe = service.create(name: "Bowl", servings: 3)
        service.addIngredient(to: recipe, name: "Poulet", quantity: 300, unit: .gram)

        let copy = service.duplicate(recipe)

        #expect(copy.name == "Bowl (copie)")
        #expect(copy.servings == 3)
        #expect(copy.ingredients.count == 1)
        #expect(copy.ingredients[0].id != recipe.ingredients[0].id)
    }

    @Test("Supprimer un ingrédient réindexe les suivants")
    func reindexesAfterRemoval() throws {
        let recipe = service.create(name: "Bowl")
        service.addIngredient(to: recipe, name: "A", quantity: 1, unit: .gram)
        let second = service.addIngredient(to: recipe, name: "B", quantity: 1, unit: .gram)
        service.addIngredient(to: recipe, name: "C", quantity: 1, unit: .gram)

        service.removeIngredient(second, from: recipe)

        let ordered = recipe.ingredients.sorted { $0.sortIndex < $1.sortIndex }
        #expect(ordered.map(\.name) == ["A", "C"])
        #expect(ordered.map(\.sortIndex) == [0, 1])
    }
}
