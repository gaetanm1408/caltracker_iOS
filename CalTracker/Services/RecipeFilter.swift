import Foundation

/// Ce que l'utilisateur accepte de voir proposer.
struct RecipeCriteria: Equatable, Sendable {
    var calorieBand: CalorieBand = .any
    var proteinFloor: ProteinFloor = .any
    /// Noms d'aliments écartés, sous leur forme normalisée.
    var excludedIngredients: Set<String> = []
    var availableEquipment: Set<CookingEquipment> = Set(CookingEquipment.allCases)
    /// Types de recettes retenus. Tous par défaut : l'assistant menus tire les
    /// repas et les collations dans des viviers séparés et n'a pas à trancher.
    var categories: Set<RecipeCategory> = Set(RecipeCategory.allCases)

    static let unrestricted = RecipeCriteria()

    var isUnrestricted: Bool { self == .unrestricted }

    /// Nombre de critères réellement posés, pour signaler à l'écran qu'un
    /// filtrage est en cours — sans quoi une liste courte passe pour un bug.
    var activeCount: Int {
        var count = 0
        if categories != Set(RecipeCategory.allCases) { count += 1 }
        if calorieBand != .any { count += 1 }
        if proteinFloor != .any { count += 1 }
        if availableEquipment != Set(CookingEquipment.allCases) { count += 1 }
        if !excludedIngredients.isEmpty { count += 1 }
        return count
    }

    /// Les critères posés, énoncés en clair.
    var summaryComponents: [String] {
        var parts: [String] = []
        if categories != Set(RecipeCategory.allCases) {
            parts.append(categories.map(\.localizedName).sorted().joined(separator: ", "))
        }
        if calorieBand != .any { parts.append(calorieBand.localizedName) }
        if proteinFloor != .any { parts.append("protéines \(proteinFloor.localizedName)") }
        let missing = Set(CookingEquipment.allCases)
            .subtracting(availableEquipment)
            .filter { !$0.isAlwaysAvailable }
        if !missing.isEmpty {
            parts.append("sans " + missing.map { $0.localizedName.lowercased() }.sorted().joined(separator: ", "))
        }
        if !excludedIngredients.isEmpty {
            parts.append("\(excludedIngredients.count) aliment(s) écarté(s)")
        }
        return parts
    }

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
        guard criteria.categories.contains(recipe.category) else { return false }
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
    /// Les mêmes aliments, rangés par famille et dans l'ordre d'affichage.
    ///
    /// Quatre-vingts noms dans une seule liste alphabétique se parcourent mal :
    /// on cherche « les légumes que je n'aime pas », pas un mot précis.
    static func groupedSelectableIngredients(in recipes: [Recipe]) -> [IngredientGroup] {
        let byFamily = Dictionary(grouping: selectableIngredients(in: recipes)) {
            IngredientFamily.of($0)
        }
        return IngredientFamily.displayOrder.compactMap { family in
            guard let names = byFamily[family], !names.isEmpty else { return nil }
            return IngredientGroup(family: family, names: names)
        }
    }

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
