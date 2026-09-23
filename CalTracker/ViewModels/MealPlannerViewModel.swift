import Foundation
import Observation

/// État de l'assistant : les paramètres du planning, le planning proposé, et
/// son écriture dans la liste de courses.
@MainActor
@Observable
final class MealPlannerViewModel {
    var request = MealPlanRequest()
    var includePantryStaples = true
    var mode: ShoppingListService.GenerationMode = .replace
    private(set) var plan: MealPlan?
    private(set) var errorMessage: String?

    private let recipes: [Recipe]
    private var seed: UInt64 = 1

    init(recipes: [Recipe]) {
        self.recipes = recipes
    }

    var meals: [Recipe] { recipes.filter { $0.category == .meal } }
    var snacks: [Recipe] { recipes.filter { $0.category == .snack } }

    /// Ce qui reste une fois les critères appliqués — le vivier réel.
    var eligibleMeals: [Recipe] {
        RecipeFilter.eligible(meals, matching: request.criteria)
    }

    var eligibleSnacks: [Recipe] {
        RecipeFilter.eligible(snacks, matching: request.criteria)
    }

    /// Aliments qu'on peut écarter, tirés des recettes elles-mêmes et rangés
    /// par famille.
    var ingredientGroups: [IngredientGroup] {
        RecipeFilter.groupedSelectableIngredients(in: recipes)
    }

    /// Ce qui manque pour composer, le cas échéant.
    ///
    /// Distingue « tu n'as pas de recette » de « tes critères n'en laissent
    /// aucune » : le remède n'est pas le même.
    var blockingMessage: String? {
        if request.mealsPerDay > 0 && eligibleMeals.isEmpty {
            return meals.isEmpty
                ? "Aucune recette de type « repas » : ajoute-en une ou ramène les repas à zéro."
                : "Aucun repas ne passe tes critères. Assouplis-les, ou ramène les repas à zéro."
        }
        if request.snacksPerDay > 0 && eligibleSnacks.isEmpty {
            return snacks.isEmpty
                ? "Aucune recette de type « collation » : ajoute-en une ou ramène les collations à zéro."
                : "Aucune collation ne passe tes critères."
        }
        if !request.isSatisfiable {
            return "Choisis au moins un repas ou une collation par jour."
        }
        return nil
    }

    var canCompose: Bool { blockingMessage == nil }

    /// Liste de courses telle qu'elle sera écrite, pour l'aperçu.
    var previewItems: [ShoppingListDraftItem] {
        guard let plan else { return [] }
        return ShoppingListBuilder.build(
            from: plan.recipeSelections(from: recipes),
            includingPantryStaples: includePantryStaples
        )
    }

    /// Ce qu'il y a à cuisiner, et en quelle quantité.
    struct Preparation: Identifiable, Hashable {
        let name: String
        let servings: Int

        var id: String { name }
    }

    var preparations: [Preparation] {
        guard let plan else { return [] }
        let byID = Dictionary(recipes.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return plan.servingsByRecipe
            .compactMap { id, servings in
                byID[id].map { Preparation(name: $0, servings: servings) }
            }
            .sorted { $0.name < $1.name }
    }

    func compose() {
        guard canCompose else {
            errorMessage = blockingMessage
            return
        }
        errorMessage = nil
        plan = MealPlanner.plan(request, meals: meals, snacks: snacks, seed: seed)
    }

    /// Repropose une autre combinaison à partir des mêmes recettes.
    func reshuffle() {
        seed &+= 1
        compose()
    }

    /// Écrit la liste de courses. Renvoie `true` quand la feuille peut fermer.
    func generate(using service: ShoppingListService) -> Bool {
        guard let plan, !plan.isEmpty else {
            errorMessage = "Compose d'abord un planning."
            return false
        }
        do {
            try service.generate(
                from: plan.recipeSelections(from: recipes),
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
