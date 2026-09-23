import Foundation

/// Ce que l'utilisateur demande à l'assistant.
struct MealPlanRequest: Equatable, Sendable {
    var days: Int = 5
    var mealsPerDay: Int = 2
    var snacksPerDay: Int = 1
    /// Portions consommées à chaque repas : deux si l'on cuisine à deux.
    var servingsPerSlot: Int = 1

    var mealSlots: Int { max(0, days) * max(0, mealsPerDay) }
    var snackSlots: Int { max(0, days) * max(0, snacksPerDay) }

    var isSatisfiable: Bool { mealSlots > 0 || snackSlots > 0 }
}

/// Une case du planning : un jour, un type, une recette.
struct MealPlanSlot: Identifiable, Hashable, Sendable {
    let id = UUID()
    let day: Int
    let category: RecipeCategory
    let recipeID: UUID
    let recipeName: String

    static func == (lhs: MealPlanSlot, rhs: MealPlanSlot) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MealPlan: Sendable {
    let request: MealPlanRequest
    let slots: [MealPlanSlot]

    var isEmpty: Bool { slots.isEmpty }

    func slots(onDay day: Int) -> [MealPlanSlot] {
        slots.filter { $0.day == day }
    }

    var days: [Int] {
        Array(Set(slots.map(\.day))).sorted()
    }

    /// Portions à préparer par recette, une fois le planning posé. C'est ce que
    /// la liste de courses doit couvrir.
    var servingsByRecipe: [UUID: Int] {
        slots.reduce(into: [:]) { totals, slot in
            totals[slot.recipeID, default: 0] += request.servingsPerSlot
        }
    }
}

/// Compose un planning de repas à partir des recettes disponibles.
///
/// Une recette choisie est cuisinée en une fois : ses portions couvrent
/// plusieurs cases consécutives. C'est ainsi qu'on cuisine réellement, et ça
/// évite de faire acheter quatre fois les ingrédients d'un plat qui en donne
/// quatre parts.
enum MealPlanner {
    static func plan(
        _ request: MealPlanRequest,
        meals: [Recipe],
        snacks: [Recipe],
        seed: UInt64 = 0
    ) -> MealPlan {
        var generator = SeededGenerator(seed: seed)
        var slots: [MealPlanSlot] = []

        slots += fill(
            slotCount: request.mealSlots,
            perDay: request.mealsPerDay,
            category: .meal,
            pool: meals,
            servingsPerSlot: request.servingsPerSlot,
            using: &generator
        )
        slots += fill(
            slotCount: request.snackSlots,
            perDay: request.snacksPerDay,
            category: .snack,
            pool: snacks,
            servingsPerSlot: request.servingsPerSlot,
            using: &generator
        )

        return MealPlan(request: request, slots: slots.sorted { $0.day < $1.day })
    }

    /// Parcourt le vivier avant de recommencer, pour ne pas servir deux fois la
    /// même chose tant que d'autres recettes n'ont pas été proposées.
    private static func fill(
        slotCount: Int,
        perDay: Int,
        category: RecipeCategory,
        pool: [Recipe],
        servingsPerSlot: Int,
        using generator: inout SeededGenerator
    ) -> [MealPlanSlot] {
        guard slotCount > 0, !pool.isEmpty, perDay > 0 else { return [] }

        var result: [MealPlanSlot] = []
        var queue: [Recipe] = []

        while result.count < slotCount {
            if queue.isEmpty {
                queue = pool.shuffled(using: &generator)
            }
            let recipe = queue.removeFirst()

            let covered = slotsCovered(by: recipe, servingsPerSlot: servingsPerSlot)
            let remaining = slotCount - result.count
            for _ in 0..<min(covered, remaining) {
                result.append(
                    MealPlanSlot(
                        day: result.count / perDay + 1,
                        category: category,
                        recipeID: recipe.id,
                        recipeName: recipe.name
                    )
                )
            }
        }
        return result
    }

    /// Nombre de cases qu'une préparation couvre, au moins une.
    static func slotsCovered(by recipe: Recipe, servingsPerSlot: Int) -> Int {
        let perSlot = max(1, servingsPerSlot)
        return max(1, recipe.servings / perSlot)
    }
}

/// Générateur reproductible : deux appels avec la même graine donnent le même
/// planning, ce qui rend les tests déterministes et permet à l'interface de
/// proposer une autre combinaison à la demande.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Un état nul rendrait le générateur muet.
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

extension MealPlan {
    /// Traduit le planning en sélections de recettes, que le moteur de liste de
    /// courses sait déjà fusionner.
    func recipeSelections(from recipes: [Recipe]) -> [RecipeSelection] {
        let byID = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return servingsByRecipe.compactMap { id, servings in
            guard let recipe = byID[id] else { return nil }
            return RecipeSelection(recipe: recipe, desiredServings: servings)
        }
        .sorted { $0.recipeName < $1.recipeName }
    }
}
