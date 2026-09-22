import Foundation
import SwiftData

/// Sample store used by SwiftUI previews.
enum PreviewData {
    @MainActor
    static func container() -> ModelContainer {
        guard let container = try? AppSchema.inMemoryContainer() else {
            fatalError("Conteneur de prévisualisation indisponible")
        }
        seed(into: container.mainContext)
        return container
    }

    @MainActor
    static func seed(into context: ModelContext) {
        context.insert(UserProfile())

        let oats = FoodProduct(
            barcode: "3175681530492",
            name: "Flocons d'avoine",
            brand: "Bjorg",
            nutritionPer100g: NutritionFacts(
                calories: 372, proteins: 13, carbohydrates: 59, fats: 7, fibers: 10, sugars: 1
            )
        )
        let yogurt = FoodProduct(
            barcode: "3033490004743",
            name: "Yaourt nature",
            brand: "Danone",
            nutritionPer100g: NutritionFacts(
                calories: 61, proteins: 4.5, carbohydrates: 5.5, fats: 2.5, sugars: 5.5
            )
        )
        let chicken = FoodProduct(
            name: "Blanc de poulet",
            nutritionPer100g: NutritionFacts(calories: 121, proteins: 25, carbohydrates: 0, fats: 2.3)
        )
        [oats, yogurt, chicken].forEach(context.insert)

        let journal = JournalService(context: context)
        journal.log(product: oats, quantityInGrams: 60, meal: .breakfast)
        journal.log(product: yogurt, quantityInGrams: 125, meal: .breakfast)
        journal.log(product: chicken, quantityInGrams: 150, meal: .lunch)

        let recipes = RecipeService(context: context)
        let bowl = recipes.create(name: "Bowl poulet-quinoa", servings: 2)
        bowl.summary = "Un bowl complet, prêt en 25 minutes."
        bowl.preparationMinutes = 25
        bowl.instructions = "Cuire le quinoa.\nPoêler le poulet.\nAssembler avec les légumes."
        recipes.addIngredient(
            to: bowl, name: "Blanc de poulet", quantity: 300, unit: .gram,
            nutritionPer100g: chicken.nutritionPer100g
        )
        recipes.addIngredient(
            to: bowl, name: "Quinoa", quantity: 150, unit: .gram,
            nutritionPer100g: NutritionFacts(calories: 368, proteins: 14, carbohydrates: 57, fats: 6)
        )
        recipes.addIngredient(to: bowl, name: "Tomates cerises", quantity: 200, unit: .gram)
        recipes.addIngredient(to: bowl, name: "Huile d'olive", quantity: 2, unit: .tablespoon, isPantryStaple: true)

        let salad = recipes.create(name: "Salade de lentilles", servings: 4)
        salad.preparationMinutes = 15
        recipes.addIngredient(to: salad, name: "Lentilles vertes", quantity: 250, unit: .gram)
        recipes.addIngredient(to: salad, name: "Tomates cerises", quantity: 150, unit: .gram)
        recipes.addIngredient(to: salad, name: "Échalotes", quantity: 2, unit: .piece)
        recipes.addIngredient(to: salad, name: "Huile d'olive", quantity: 3, unit: .tablespoon, isPantryStaple: true)

        try? ShoppingListService(context: context).generate(
            from: [RecipeSelection(recipe: bowl), RecipeSelection(recipe: salad)]
        )
    }

    static let sampleRemoteFoods: [RemoteFood] = [
        RemoteFood(
            barcode: "3175681530492",
            name: "Flocons d'avoine",
            brand: "Bjorg",
            imageURLString: nil,
            servingSizeInGrams: 40,
            nutritionPer100g: NutritionFacts(
                calories: 372, proteins: 13, carbohydrates: 59, fats: 7, fibers: 10, sugars: 1
            )
        ),
        RemoteFood(
            barcode: "3033490004743",
            name: "Yaourt nature",
            brand: "Danone",
            imageURLString: nil,
            servingSizeInGrams: 125,
            nutritionPer100g: NutritionFacts(
                calories: 61, proteins: 4.5, carbohydrates: 5.5, fats: 2.5, sugars: 5.5
            )
        )
    ]
}

/// Offline client returning fixtures, for previews and tests.
struct StubFoodDatabaseClient: FoodDatabaseClient {
    var foods: [RemoteFood] = PreviewData.sampleRemoteFoods
    var error: FoodDatabaseError?
    var delay: Duration = .zero

    func searchProducts(query: String, page: Int) async throws -> [RemoteFood] {
        if delay > .zero { try? await Task.sleep(for: delay) }
        if let error { throw error }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(query) || query.count >= 2 }
    }

    func product(barcode: String) async throws -> RemoteFood? {
        if let error { throw error }
        return foods.first { $0.barcode == barcode }
    }
}
