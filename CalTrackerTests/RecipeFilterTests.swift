import Foundation
import SwiftData
import Testing

@testable import CalTracker

@MainActor
@Suite("Filtrage des recettes")
struct RecipeFilterTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let service: RecipeService

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
        service = RecipeService(context: context)
    }

    /// Construit une recette dont une portion porte les apports voulus.
    @discardableResult
    private func makeRecipe(
        _ name: String,
        caloriesPerServing: Double,
        proteinsPerServing: Double,
        category: RecipeCategory = .meal,
        equipment: Set<CookingEquipment> = [],
        ingredients: [String] = ["Poulet"]
    ) -> Recipe {
        let recipe = service.create(name: name, servings: 1)
        recipe.category = category
        recipe.equipment = equipment
        // Cent grammes d'un ingrédient dont les valeurs pour 100 g sont
        // exactement celles attendues par portion.
        service.addIngredient(
            to: recipe,
            name: ingredients[0],
            quantity: 100,
            unit: .gram,
            nutritionPer100g: NutritionFacts(
                calories: caloriesPerServing,
                proteins: proteinsPerServing,
                carbohydrates: 0,
                fats: 0
            )
        )
        for extra in ingredients.dropFirst() {
            service.addIngredient(to: recipe, name: extra, quantity: 50, unit: .gram)
        }
        return recipe
    }

    @Test("Sans critère, tout passe")
    func acceptsEverythingWhenUnrestricted() {
        let recipes = [
            makeRecipe("Léger", caloriesPerServing: 450, proteinsPerServing: 30),
            makeRecipe("Costaud", caloriesPerServing: 900, proteinsPerServing: 60)
        ]

        #expect(RecipeCriteria.unrestricted.isUnrestricted)
        #expect(RecipeFilter.eligible(recipes, matching: .unrestricted).count == 2)
    }

    @Test("La fourchette de calories retient les bonnes assiettes")
    func filtersByCalorieBand() {
        let recipes = [
            makeRecipe("Léger", caloriesPerServing: 450, proteinsPerServing: 30),
            makeRecipe("Équilibré", caloriesPerServing: 700, proteinsPerServing: 40),
            makeRecipe("Costaud", caloriesPerServing: 900, proteinsPerServing: 60)
        ]

        var criteria = RecipeCriteria()
        criteria.calorieBand = .light
        #expect(RecipeFilter.eligible(recipes, matching: criteria).map(\.name) == ["Léger"])

        criteria.calorieBand = .balanced
        #expect(RecipeFilter.eligible(recipes, matching: criteria).map(\.name) == ["Équilibré"])

        criteria.calorieBand = .hearty
        #expect(RecipeFilter.eligible(recipes, matching: criteria).map(\.name) == ["Costaud"])
    }

    @Test("« Léger » garde les assiettes les plus légères")
    func lightBandHasNoFloor() {
        // Une omelette à 330 kcal est plus légère que « léger » : l'écarter
        // quand on demande léger n'aurait aucun sens.
        let recipes = [
            makeRecipe("Très léger", caloriesPerServing: 330, proteinsPerServing: 50),
            makeRecipe("Léger", caloriesPerServing: 450, proteinsPerServing: 30),
            makeRecipe("Équilibré", caloriesPerServing: 700, proteinsPerServing: 40)
        ]

        var criteria = RecipeCriteria()
        criteria.calorieBand = .light

        #expect(RecipeFilter.eligible(recipes, matching: criteria).map(\.name) == ["Très léger", "Léger"])
    }

    @Test("Le plancher de protéines écarte les assiettes trop pauvres")
    func filtersByProteinFloor() {
        let recipes = [
            makeRecipe("Maigre", caloriesPerServing: 500, proteinsPerServing: 25),
            makeRecipe("Correct", caloriesPerServing: 500, proteinsPerServing: 35),
            makeRecipe("Généreux", caloriesPerServing: 500, proteinsPerServing: 55)
        ]

        var criteria = RecipeCriteria()
        criteria.proteinFloor = .thirty
        #expect(RecipeFilter.eligible(recipes, matching: criteria).count == 2)

        criteria.proteinFloor = .fifty
        #expect(RecipeFilter.eligible(recipes, matching: criteria).map(\.name) == ["Généreux"])
    }

    @Test("Les collations échappent aux bornes prévues pour les assiettes")
    func sparesSnacksFromPlateRules() {
        let snack = makeRecipe(
            "Skyr", caloriesPerServing: 250, proteinsPerServing: 20, category: .snack
        )

        var criteria = RecipeCriteria()
        criteria.calorieBand = .hearty
        criteria.proteinFloor = .fifty

        // Une collation à 250 kcal ne satisferait aucune de ces deux bornes.
        #expect(RecipeFilter.isEligible(snack, matching: criteria))
    }

    @Test("Une recette sans apports calculés n'est pas écartée")
    func keepsRecipesWithoutNutrition() {
        let recipe = service.create(name: "Saisie à la main", servings: 1)
        service.addIngredient(to: recipe, name: "Quelque chose", quantity: 100, unit: .gram)

        var criteria = RecipeCriteria()
        criteria.proteinFloor = .fifty

        #expect(!recipe.hasNutritionData)
        #expect(RecipeFilter.isEligible(recipe, matching: criteria))
    }

    @Test("Un aliment exclu retire les recettes qui en contiennent")
    func excludesDislikedIngredients() {
        let recipes = [
            makeRecipe("Au saumon", caloriesPerServing: 500, proteinsPerServing: 40,
                       ingredients: ["Saumon", "Riz"]),
            makeRecipe("Au poulet", caloriesPerServing: 500, proteinsPerServing: 40,
                       ingredients: ["Poulet", "Riz"])
        ]

        var criteria = RecipeCriteria()
        criteria.exclude("saumon")

        #expect(criteria.excludes("Saumon"))
        #expect(RecipeFilter.eligible(recipes, matching: criteria).map(\.name) == ["Au poulet"])
    }

    @Test("L'exclusion ignore accents, casse et pluriel")
    func matchesExclusionsLoosely() {
        let recipe = makeRecipe("Aux échalotes", caloriesPerServing: 500, proteinsPerServing: 40,
                                ingredients: ["Échalotes"])

        var criteria = RecipeCriteria()
        criteria.exclude("echalote")

        #expect(!RecipeFilter.isEligible(recipe, matching: criteria))
    }

    @Test("Le matériel manquant écarte la recette, pas l'assemblage")
    func filtersByEquipment() {
        let roasted = makeRecipe("Au four", caloriesPerServing: 500, proteinsPerServing: 40,
                                 equipment: [.oven])
        let assembled = makeRecipe("Sans cuisson", caloriesPerServing: 500, proteinsPerServing: 40,
                                   equipment: [.none])

        var criteria = RecipeCriteria()
        criteria.availableEquipment = [.stovetop]

        #expect(!RecipeFilter.isEligible(roasted, matching: criteria))
        // « Sans cuisson » est toujours réalisable, quel que soit le matériel.
        #expect(RecipeFilter.isEligible(assembled, matching: criteria))
    }

    @Test("Une recette réclamant plusieurs appareils les exige tous")
    func requiresEveryPieceOfEquipment() {
        let recipe = makeRecipe("Four et plaque", caloriesPerServing: 500, proteinsPerServing: 40,
                                equipment: [.oven, .stovetop])

        var criteria = RecipeCriteria()
        criteria.availableEquipment = [.oven]
        #expect(!RecipeFilter.isEligible(recipe, matching: criteria))

        criteria.availableEquipment = [.oven, .stovetop]
        #expect(RecipeFilter.isEligible(recipe, matching: criteria))
    }

    @Test("Le type de recette restreint ce qui est affiché")
    func filtersByCategory() {
        let recipes = [
            makeRecipe("Assiette", caloriesPerServing: 500, proteinsPerServing: 40),
            makeRecipe("Encas", caloriesPerServing: 250, proteinsPerServing: 20, category: .snack)
        ]

        // Par défaut, les deux types passent : l'assistant menus tire ses
        // viviers séparément et ne doit rien perdre.
        #expect(RecipeFilter.eligible(recipes, matching: .unrestricted).count == 2)

        var criteria = RecipeCriteria()
        criteria.categories = [.meal]
        #expect(RecipeFilter.eligible(recipes, matching: criteria).map(\.name) == ["Assiette"])

        criteria.categories = [.snack]
        #expect(RecipeFilter.eligible(recipes, matching: criteria).map(\.name) == ["Encas"])
    }

    @Test("Les critères posés se comptent et s'énoncent")
    func describesActiveCriteria() {
        var criteria = RecipeCriteria()
        #expect(criteria.activeCount == 0)
        #expect(criteria.summaryComponents.isEmpty)

        criteria.calorieBand = .hearty
        criteria.proteinFloor = .forty
        criteria.categories = [.meal]
        criteria.availableEquipment.remove(.oven)
        criteria.exclude("Saumon")

        #expect(criteria.activeCount == 5)
        let summary = criteria.summaryComponents.joined(separator: " · ")
        #expect(summary.contains("Repas"))
        #expect(summary.contains("Costaud"))
        #expect(summary.contains("sans four"))
        #expect(summary.contains("1 aliment"))
    }

    @Test("Retirer puis remettre un appareil ne laisse aucune trace")
    func equipmentReturnsToUnrestricted() {
        var criteria = RecipeCriteria()
        criteria.availableEquipment.remove(.airFryer)
        #expect(criteria.activeCount == 1)

        criteria.availableEquipment.insert(.airFryer)
        #expect(criteria.isUnrestricted)
    }

    @Test("Les aliments proposés sont rangés par famille, dans l'ordre")
    func groupsSelectableIngredientsByFamily() throws {
        makeRecipe(
            "Plat", caloriesPerServing: 500, proteinsPerServing: 40,
            ingredients: ["Blanc de poulet", "Riz basmati cuit", "Brocoli", "Yaourt grec 2 %"]
        )

        let groups = RecipeFilter.groupedSelectableIngredients(in: try service.allRecipes())

        #expect(groups.map(\.family) == [.vegetables, .meat, .dairyAndEggs, .starches])
        #expect(groups.flatMap(\.names).count == 4)
        #expect(!groups.contains { $0.names.isEmpty })
    }

    @Test("Les aliments proposés à l'exclusion viennent des recettes")
    func listsSelectableIngredients() {
        makeRecipe("A", caloriesPerServing: 500, proteinsPerServing: 40, ingredients: ["Saumon", "Riz"])
        makeRecipe("B", caloriesPerServing: 500, proteinsPerServing: 40, ingredients: ["saumons", "Quinoa"])
        let withStaple = service.create(name: "C", servings: 1)
        service.addIngredient(to: withStaple, name: "Huile d'olive", quantity: 1,
                              unit: .tablespoon, isPantryStaple: true)

        let selectable = RecipeFilter.selectableIngredients(in: try! service.allRecipes())

        // « Saumon » et « saumons » désignent le même aliment.
        #expect(selectable.filter { $0.localizedCaseInsensitiveContains("saumon") }.count == 1)
        #expect(selectable.contains("Riz"))
        #expect(selectable.contains("Quinoa"))
        // Les produits de placard ne valent pas la peine d'être exclus.
        #expect(!selectable.contains("Huile d'olive"))
    }
}

@MainActor
@Suite("Critères appliqués au planning")
struct MealPlannerCriteriaTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let service: RecipeService

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
        service = RecipeService(context: context)
    }

    private func makeMeal(_ name: String, proteins: Double, ingredient: String = "Poulet") -> Recipe {
        let recipe = service.create(name: name, servings: 1)
        service.addIngredient(
            to: recipe, name: ingredient, quantity: 100, unit: .gram,
            nutritionPer100g: NutritionFacts(calories: 500, proteins: proteins)
        )
        return recipe
    }

    @Test("Une recette écartée n'apparaît jamais au planning")
    func neverPlansExcludedRecipes() {
        let meals = [
            makeMeal("Riche", proteins: 55),
            makeMeal("Pauvre", proteins: 20)
        ]
        var request = MealPlanRequest(days: 4, mealsPerDay: 2, snacksPerDay: 0, servingsPerSlot: 1)
        request.criteria.proteinFloor = .fifty

        let plan = MealPlanner.plan(request, meals: meals, snacks: [], seed: 5)

        #expect(plan.slots.count == 8)
        #expect(Set(plan.slots.map(\.recipeName)) == ["Riche"])
    }

    @Test("Des critères trop stricts donnent un planning vide plutôt que faux")
    func producesEmptyPlanWhenNothingMatches() {
        var request = MealPlanRequest(days: 3, mealsPerDay: 2, snacksPerDay: 0, servingsPerSlot: 1)
        request.criteria.proteinFloor = .fifty

        let plan = MealPlanner.plan(request, meals: [makeMeal("Pauvre", proteins: 10)], snacks: [], seed: 1)

        #expect(plan.isEmpty)
    }
}
