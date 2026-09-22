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
