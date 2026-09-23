import Foundation
import SwiftData
import Testing

@testable import CalTracker

@MainActor
@Suite("Assistant de planification")
struct MealPlannerTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let service: RecipeService

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
        service = RecipeService(context: context)
    }

    @discardableResult
    private func makeRecipe(_ name: String, servings: Int, category: RecipeCategory = .meal) -> Recipe {
        let recipe = service.create(name: name, servings: servings)
        recipe.category = category
        service.addIngredient(to: recipe, name: "Ingrédient \(name)", quantity: 100, unit: .gram)
        return recipe
    }

    @Test("Le planning remplit exactement les cases demandées")
    func fillsEverySlot() {
        let meals = (1...4).map { makeRecipe("Repas \($0)", servings: 1) }
        let snacks = [makeRecipe("Collation", servings: 1, category: .snack)]
        let request = MealPlanRequest(days: 3, mealsPerDay: 2, snacksPerDay: 1, servingsPerSlot: 1)

        let plan = MealPlanner.plan(request, meals: meals, snacks: snacks, seed: 7)

        #expect(plan.slots.filter { $0.category == .meal }.count == 6)
        #expect(plan.slots.filter { $0.category == .snack }.count == 3)
        #expect(plan.days == [1, 2, 3])
    }

    @Test("Un plat en lot couvre plusieurs repas")
    func batchCookingCoversSeveralSlots() {
        // Un seul plat de 4 portions pour 4 repas : il est cuisiné une fois.
        let chili = makeRecipe("Chili", servings: 4)
        let request = MealPlanRequest(days: 2, mealsPerDay: 2, snacksPerDay: 0, servingsPerSlot: 1)

        let plan = MealPlanner.plan(request, meals: [chili], snacks: [], seed: 1)

        #expect(plan.slots.count == 4)
        #expect(plan.servingsByRecipe[chili.id] == 4)
    }

    @Test("Cuisiner pour deux réduit le nombre de repas couverts")
    func servingsPerSlotReducesCoverage() {
        let chili = makeRecipe("Chili", servings: 4)

        #expect(MealPlanner.slotsCovered(by: chili, servingsPerSlot: 1) == 4)
        #expect(MealPlanner.slotsCovered(by: chili, servingsPerSlot: 2) == 2)
        // Une recette plus petite que la tablée couvre quand même un repas.
        #expect(MealPlanner.slotsCovered(by: chili, servingsPerSlot: 6) == 1)
    }

    @Test("Toutes les recettes sont proposées avant qu'une ne revienne")
    func exhaustsPoolBeforeRepeating() {
        let meals = (1...3).map { makeRecipe("Repas \($0)", servings: 1) }
        let request = MealPlanRequest(days: 3, mealsPerDay: 1, snacksPerDay: 0, servingsPerSlot: 1)

        let plan = MealPlanner.plan(request, meals: meals, snacks: [], seed: 3)

        #expect(Set(plan.slots.map(\.recipeID)).count == 3)
    }

    @Test("Une même graine redonne le même menu, une autre en propose un autre")
    func isReproducibleAndReshuffleable() {
        let meals = (1...6).map { makeRecipe("Repas \($0)", servings: 1) }
        let request = MealPlanRequest(days: 3, mealsPerDay: 2, snacksPerDay: 0, servingsPerSlot: 1)

        let first = MealPlanner.plan(request, meals: meals, snacks: [], seed: 42)
        let same = MealPlanner.plan(request, meals: meals, snacks: [], seed: 42)
        let other = MealPlanner.plan(request, meals: meals, snacks: [], seed: 43)

        #expect(first.slots.map(\.recipeName) == same.slots.map(\.recipeName))
        #expect(first.slots.map(\.recipeName) != other.slots.map(\.recipeName))
    }

    @Test("Sans recette disponible, aucune case n'est remplie")
    func handlesEmptyPool() {
        let plan = MealPlanner.plan(
            MealPlanRequest(days: 3, mealsPerDay: 2, snacksPerDay: 1, servingsPerSlot: 1),
            meals: [],
            snacks: []
        )

        #expect(plan.isEmpty)
    }

    @Test("Le planning se traduit en sélections que la liste sait fusionner")
    func convertsToShoppingSelections() throws {
        let bowl = service.create(name: "Bowl", servings: 2)
        service.addIngredient(to: bowl, name: "Poulet", quantity: 300, unit: .gram)
        let request = MealPlanRequest(days: 2, mealsPerDay: 2, snacksPerDay: 0, servingsPerSlot: 1)

        let plan = MealPlanner.plan(request, meals: [bowl], snacks: [], seed: 1)
        let selections = plan.recipeSelections(from: [bowl])

        // Quatre repas d'une recette qui en donne deux : double dose.
        #expect(selections.count == 1)
        #expect(selections[0].desiredServings == 4)

        let items = ShoppingListBuilder.build(from: selections)
        #expect(items.first?.quantity == 600)
    }
}

@MainActor
@Suite("État de l'assistant")
struct MealPlannerViewModelTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let service: RecipeService

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
        service = RecipeService(context: context)
    }

    private func makeRecipe(_ name: String, category: RecipeCategory) -> Recipe {
        let recipe = service.create(name: name, servings: 2)
        recipe.category = category
        service.addIngredient(to: recipe, name: "Ingrédient", quantity: 100, unit: .gram)
        return recipe
    }

    @Test("L'absence de collation est signalée plutôt que subie")
    func reportsMissingSnacks() {
        let viewModel = MealPlannerViewModel(recipes: [makeRecipe("Bowl", category: .meal)])
        viewModel.request = MealPlanRequest(days: 2, mealsPerDay: 2, snacksPerDay: 1, servingsPerSlot: 1)

        #expect(!viewModel.canCompose)
        #expect(viewModel.blockingMessage?.contains("collation") == true)
    }

    @Test("Ramener les collations à zéro débloque la composition")
    func composesWithoutSnacks() {
        let viewModel = MealPlannerViewModel(recipes: [makeRecipe("Bowl", category: .meal)])
        viewModel.request = MealPlanRequest(days: 2, mealsPerDay: 2, snacksPerDay: 0, servingsPerSlot: 1)

        viewModel.compose()

        #expect(viewModel.canCompose)
        #expect(viewModel.plan?.slots.count == 4)
        #expect(!viewModel.previewItems.isEmpty)
    }

    @Test("Proposer autre chose change le menu")
    func reshuffleChangesPlan() {
        let recipes = (1...6).map { makeRecipe("Repas \($0)", category: .meal) }
        let viewModel = MealPlannerViewModel(recipes: recipes)
        viewModel.request = MealPlanRequest(days: 3, mealsPerDay: 2, snacksPerDay: 0, servingsPerSlot: 1)

        viewModel.compose()
        let first = viewModel.plan?.slots.map(\.recipeName)
        viewModel.reshuffle()

        #expect(viewModel.plan?.slots.map(\.recipeName) != first)
    }

    @Test("La génération écrit la liste de courses")
    func writesShoppingList() throws {
        let viewModel = MealPlannerViewModel(recipes: [makeRecipe("Bowl", category: .meal)])
        viewModel.request = MealPlanRequest(days: 1, mealsPerDay: 2, snacksPerDay: 0, servingsPerSlot: 1)
        viewModel.compose()

        let shopping = ShoppingListService(context: context)
        #expect(viewModel.generate(using: shopping))
        #expect(try shopping.allItems().count == 1)
    }

    @Test("Générer sans planning est refusé")
    func refusesWithoutPlan() throws {
        let viewModel = MealPlannerViewModel(recipes: [makeRecipe("Bowl", category: .meal)])

        #expect(!viewModel.generate(using: ShoppingListService(context: context)))
        #expect(viewModel.errorMessage != nil)
    }
}
