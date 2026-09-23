import Foundation

/// Ce que l'utilisateur accepte de voir proposer.
struct RecipeCriteria: Equatable, Sendable {
    var calorieBand: CalorieBand = .any
    var proteinFloor: ProteinFloor = .any
    /// Noms d'aliments écartés, sous leur forme normalisée.
    var excludedIngredients: Set<String> = []
    var availableEquipment: Set<CookingEquipment> = Set(CookingEquipment.allCases)

    static let unrestricted = RecipeCriteria()

    var isUnrestricted: Bool { self == .unrestricted }

    mutating func exclude(_ ingredientName: String) {
        excludedIngredients.insert(ShoppingListBuilder.normalize(ingredientName))
    }

    mutating func allow(_ ingredientName: String) {
        excludedIngredients.remove(ShoppingListBuilder.normalize(ingredientName))
    }

    func excludes(_ ingredientName: String) -> Bool {
        excludedIngredients.contains(ShoppingListBuilder.normalize(ingredientName))
    }
}

/// Retient les recettes compatibles avec les critères.
enum RecipeFilter {
    static func eligible(_ recipes: [Recipe], matching criteria: RecipeCriteria) -> [Recipe] {
        recipes.filter { isEligible($0, matching: criteria) }
    }

    static func isEligible(_ recipe: Recipe, matching criteria: RecipeCriteria) -> Bool {
        guard hasAvailableEquipment(recipe, matching: criteria) else { return false }
        guard avoidsExcludedIngredients(recipe, matching: criteria) else { return false }
        return matchesNutrition(recipe, matching: criteria)
    }

    /// Une recette sans matériel déclaré s'assemble sans cuisson : rien ne
    /// justifie de l'écarter.
    private static func hasAvailableEquipment(_ recipe: Recipe, matching criteria: RecipeCriteria) -> Bool {
        let required = recipe.equipment.filter { !$0.isAlwaysAvailable }
        return required.isSubset(of: criteria.availableEquipment)
    }

    private static func avoidsExcludedIngredients(_ recipe: Recipe, matching criteria: RecipeCriteria) -> Bool {
        guard !criteria.excludedIngredients.isEmpty else { return true }
        return recipe.normalizedIngredientNames.isDisjoint(with: criteria.excludedIngredients)
    }

    /// Les fourchettes de calories et le plancher de protéines ne visent que
    /// les assiettes. Une collation tourne autour de 250 kcal ; la soumettre
    /// aux mêmes bornes les écarterait toutes.
    private static func matchesNutrition(_ recipe: Recipe, matching criteria: RecipeCriteria) -> Bool {
        guard recipe.category == .meal else { return true }
        // Sans apports calculés, rien ne permet de juger : on laisse passer
        // plutôt que d'écarter une recette saisie à la main.
        guard recipe.hasNutritionData else { return true }

        let perServing = recipe.nutritionPerServing
        return criteria.calorieBand.accepts(perServing.calories)
            && criteria.proteinFloor.accepts(perServing.proteins)
    }

    /// Tous les ingrédients des recettes fournies, dédoublonnés et triés :
    /// c'est la liste dans laquelle choisir ce qu'on ne veut pas voir.
    ///
    /// La proposer depuis les recettes elles-mêmes évite d'entretenir un
    /// catalogue d'aliments à part, et n'offre que des choix qui changent
    /// réellement quelque chose.
    static func selectableIngredients(in recipes: [Recipe]) -> [String] {
        var byNormalized: [String: String] = [:]
        for recipe in recipes {
            for ingredient in recipe.ingredients where !ingredient.isPantryStaple {
                let key = ShoppingListBuilder.normalize(ingredient.name)
                guard !key.isEmpty, byNormalized[key] == nil else { continue }
                byNormalized[key] = ingredient.name
            }
        }
        return byNormalized.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
