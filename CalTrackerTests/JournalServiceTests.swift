import Foundation
import SwiftData
import Testing

@testable import CalTracker

@MainActor
@Suite("Journal alimentaire")
struct JournalServiceTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let journal: JournalService

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
        journal = JournalService(context: context)
    }

    private func makeProduct(
        name: String = "Flocons d'avoine",
        facts: NutritionFacts = NutritionFacts(calories: 372, proteins: 13, carbohydrates: 59, fats: 7)
    ) -> FoodProduct {
        let product = FoodProduct(name: name, nutritionPer100g: facts)
        context.insert(product)
        return product
    }

    @Test("Un aliment consigné apparaît dans la journée correspondante")
    func logsEntryForDay() throws {
        let product = makeProduct()
        journal.log(product: product, quantityInGrams: 50, meal: .breakfast)

        let entries = try journal.entries(for: .now)
        #expect(entries.count == 1)
        #expect(entries[0].meal == .breakfast)
        #expect(entries[0].consumedNutrition.calories == 186)
    }

    @Test("Les entrées d'un autre jour ne sont pas renvoyées")
    func isolatesDays() throws {
        let product = makeProduct()
        journal.log(product: product, quantityInGrams: 100, meal: .lunch)
        journal.log(product: product, quantityInGrams: 100, meal: .lunch, on: Date.now.addingDays(-1))

        #expect(try journal.entries(for: .now).count == 1)
        #expect(try journal.entries(for: Date.now.addingDays(-1)).count == 1)
        #expect(try journal.entries(for: Date.now.addingDays(-2)).isEmpty)
    }

    @Test("Le résumé du jour additionne toutes les entrées")
    func summarizesDay() throws {
        let oats = makeProduct()
        let chicken = makeProduct(
            name: "Poulet",
            facts: NutritionFacts(calories: 121, proteins: 25, carbohydrates: 0, fats: 2.3)
        )
        journal.log(product: oats, quantityInGrams: 50, meal: .breakfast)
        journal.log(product: chicken, quantityInGrams: 200, meal: .lunch)

        let summary = try journal.summary(for: .now, goals: .default)

        #expect(summary.entryCount == 2)
        #expect(abs(summary.consumed.calories - (186 + 242)) < 0.01)
        #expect(abs(summary.consumedGrams(for: .proteins) - (6.5 + 50)) < 0.01)
        #expect(!summary.isOverCalorieGoal)
    }

    @Test("Les apports sont figés à l'enregistrement")
    func snapshotsNutrition() throws {
        let product = makeProduct()
        journal.log(product: product, quantityInGrams: 100, meal: .snack)

        // Une correction ultérieure de la fiche produit ne réécrit pas l'historique.
        product.nutritionPer100g = NutritionFacts(calories: 1, proteins: 1, carbohydrates: 1, fats: 1)

        let entry = try #require(try journal.entries(for: .now).first)
        #expect(entry.consumedNutrition.calories == 372)
    }

    @Test("Modifier une entrée met à jour ses apports")
    func updatesEntry() throws {
        let product = makeProduct()
        let entry = journal.log(product: product, quantityInGrams: 100, meal: .snack)

        journal.update(entry, quantityInGrams: 25, meal: .breakfast)

        #expect(entry.meal == .breakfast)
        #expect(entry.consumedNutrition.calories == 93)
    }

    @Test("Supprimer une entrée la retire du journal")
    func deletesEntry() throws {
        let product = makeProduct()
        let entry = journal.log(product: product, quantityInGrams: 100, meal: .dinner)

        journal.delete(entry)

        #expect(try journal.entries(for: .now).isEmpty)
    }

    @Test("Déplacer une entrée change son jour de rattachement")
    func movesEntryToAnotherDay() throws {
        let product = makeProduct()
        let entry = journal.log(product: product, quantityInGrams: 100, meal: .lunch)

        journal.move(entry, to: Date.now.addingDays(-3))

        #expect(try journal.entries(for: .now).isEmpty)
        #expect(try journal.entries(for: Date.now.addingDays(-3)).count == 1)
    }

    @Test("Le produit consigné remonte dans les récents")
    func marksProductAsRecentlyUsed() throws {
        let product = makeProduct()
        journal.log(product: product, quantityInGrams: 100, meal: .lunch)

        let recents = try ProductRepository(context: context).recentlyUsed()
        #expect(recents.count == 1)
        #expect(recents[0].name == product.name)
    }

    @Test("Une recette est consignée comme une ligne unique")
    func logsRecipeAsSingleEntry() throws {
        let recipes = RecipeService(context: context)
        let recipe = recipes.create(name: "Bowl", servings: 2)
        recipes.addIngredient(
            to: recipe, name: "Poulet", quantity: 300, unit: .gram,
            nutritionPer100g: NutritionFacts(calories: 121, proteins: 25, carbohydrates: 0, fats: 2.3)
        )
        recipes.addIngredient(
            to: recipe, name: "Quinoa", quantity: 100, unit: .gram,
            nutritionPer100g: NutritionFacts(calories: 368, proteins: 14, carbohydrates: 57, fats: 6)
        )

        let entry = try #require(journal.log(recipe: recipe, servings: 1, meal: .dinner))

        #expect(entry.productNameSnapshot == "Bowl")
        // Une portion, soit la moitié des apports totaux de la recette.
        #expect(abs(entry.consumedNutrition.calories - recipe.nutritionPerServing.calories) < 0.5)
        #expect(try journal.entries(for: .now).count == 1)
    }

    @Test("Une recette sans données nutritionnelles n'est pas consignée")
    func refusesRecipeWithoutNutrition() throws {
        let recipes = RecipeService(context: context)
        let recipe = recipes.create(name: "Sans macros", servings: 2)
        recipes.addIngredient(to: recipe, name: "Tomates", quantity: 200, unit: .gram)

        #expect(journal.log(recipe: recipe, servings: 1, meal: .dinner) == nil)
    }
}
