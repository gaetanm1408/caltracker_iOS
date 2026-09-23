import Foundation
import Testing

@testable import CalTracker

@MainActor
@Suite("Recherche et scan de code-barres")
struct FoodSearchViewModelTests {
    @Test("Un code-barres connu renvoie le produit et l'affiche")
    func findsKnownBarcode() async throws {
        let viewModel = FoodSearchViewModel(client: StubFoodDatabaseClient())

        let scanned = await viewModel.lookup(barcode: "3175681530492")
        let food = try #require(scanned)

        #expect(food.name == "Flocons d'avoine")
        #expect(viewModel.state == .results([food]))
        // Le champ de recherche reflète le produit scanné.
        #expect(viewModel.query == "Flocons d'avoine")
    }

    @Test("Un code-barres inconnu laisse l'écran sur un résultat vide")
    func reportsUnknownBarcode() async {
        let viewModel = FoodSearchViewModel(client: StubFoodDatabaseClient())

        let scanned = await viewModel.lookup(barcode: "0000000000000")

        #expect(scanned == nil)
        #expect(viewModel.state == .empty(query: "0000000000000"))
    }

    @Test("Une panne réseau pendant le scan est rapportée à l'écran")
    func reportsNetworkFailure() async {
        let viewModel = FoodSearchViewModel(client: StubFoodDatabaseClient(error: .offline))

        let scanned = await viewModel.lookup(barcode: "3175681530492")

        #expect(scanned == nil)
        guard case .failed(let message) = viewModel.state else {
            Issue.record("État attendu : échec, obtenu \(viewModel.state)")
            return
        }
        #expect(message == FoodDatabaseError.offline.errorDescription)
    }

    @Test("Une requête trop courte ne lance aucune recherche")
    func ignoresShortQueries() {
        let viewModel = FoodSearchViewModel(client: StubFoodDatabaseClient())

        viewModel.updateQuery("a")

        #expect(viewModel.state == .idle)
    }
}

@MainActor
@Suite("Filtre par catégorie")
struct FoodSearchCategoryTests {
    private func food(_ name: String, categories: [String]) -> RemoteFood {
        RemoteFood(
            barcode: name,
            name: name,
            brand: nil,
            imageURLString: nil,
            servingSizeInGrams: nil,
            nutritionPer100g: NutritionFacts(calories: 100, proteins: 5, carbohydrates: 10, fats: 2),
            categories: categories
        )
    }

    private func searched() async -> FoodSearchViewModel {
        let client = StubFoodDatabaseClient(foods: [
            food("Nutella", categories: ["Petit-déjeuners", "Pâtes à tartiner"]),
            food("Confiture", categories: ["Petit-déjeuners", "Pâtes à tartiner"]),
            food("Céréales", categories: ["Petit-déjeuners"]),
            food("Jambon", categories: ["Charcuteries"])
        ])
        let viewModel = FoodSearchViewModel(client: client)
        viewModel.updateQuery("petit")
        viewModel.searchNow()
        // Laisse la tâche de recherche se terminer.
        try? await Task.sleep(for: .milliseconds(50))
        return viewModel
    }

    @Test("Les catégories sont classées par fréquence, les isolées écartées")
    func ranksCategoriesByFrequency() async {
        let viewModel = await searched()

        // Les plus fréquentes d'abord ; « Charcuteries » ne porte qu'un produit
        // mais reste proposée, elle permet de le retrouver.
        #expect(viewModel.availableCategories == ["Petit-déjeuners", "Pâtes à tartiner", "Charcuteries"])
    }

    @Test("Choisir une catégorie restreint les résultats")
    func filtersBySelectedCategory() async {
        let viewModel = await searched()

        viewModel.toggleCategory("Pâtes à tartiner")

        #expect(viewModel.visibleResults.map(\.name) == ["Nutella", "Confiture"])
    }

    @Test("Toucher deux fois la même catégorie retire le filtre")
    func togglesCategoryOff() async {
        let viewModel = await searched()

        viewModel.toggleCategory("Pâtes à tartiner")
        viewModel.toggleCategory("Pâtes à tartiner")

        #expect(viewModel.selectedCategory == nil)
        #expect(viewModel.visibleResults.count == 4)
    }

    @Test("Une nouvelle recherche repart sans filtre")
    func clearsFilterOnNewSearch() async {
        let viewModel = await searched()
        viewModel.toggleCategory("Charcuteries")

        viewModel.updateQuery("autre chose")
        viewModel.searchNow()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.selectedCategory == nil)
    }
}
