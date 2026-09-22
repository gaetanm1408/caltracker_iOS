import Foundation
import Testing

@testable import CalTracker

@Suite("Décodage Open Food Facts")
struct OpenFoodFactsMappingTests {
    private func decodeSearch(_ json: String) throws -> OFFSearchResponse {
        try JSONDecoder().decode(OFFSearchResponse.self, from: Data(json.utf8))
    }

    @Test("Une réponse de recherche est convertie en produits exploitables")
    func decodesSearchResponse() throws {
        let response = try decodeSearch(
            """
            {
              "count": 1,
              "page": 1,
              "page_size": 24,
              "products": [
                {
                  "code": "3175681530492",
                  "product_name": "Flocons d'avoine",
                  "brands": "Bjorg, Distriborg",
                  "quantity": "500 g",
                  "serving_quantity": 40,
                  "nutriments": {
                    "energy-kcal_100g": 372,
                    "proteins_100g": 13,
                    "carbohydrates_100g": 59,
                    "fat_100g": 7,
                    "fiber_100g": 10
                  }
                }
              ]
            }
            """
        )

        let foods = response.products.compactMap { $0.toRemoteFood() }
        #expect(foods.count == 1)

        let food = try #require(foods.first)
        #expect(food.barcode == "3175681530492")
        #expect(food.name == "Flocons d'avoine")
        // Seule la première marque est retenue.
        #expect(food.brand == "Bjorg")
        #expect(food.servingSizeInGrams == 40)
        #expect(food.nutritionPer100g.calories == 372)
        #expect(food.nutritionPer100g.fibers == 10)
    }

    @Test("Les nombres transmis en texte sont acceptés")
    func decodesStringNumbers() throws {
        let response = try decodeSearch(
            """
            {
              "products": [
                {
                  "code": 3033490004743,
                  "product_name": "Yaourt nature",
                  "serving_quantity": "125",
                  "nutriments": {
                    "energy-kcal_100g": "61",
                    "proteins_100g": "4,5",
                    "carbohydrates_100g": "5.5",
                    "fat_100g": 2.5
                  }
                }
              ]
            }
            """
        )

        let food = try #require(response.products.first?.toRemoteFood())
        // Le code-barres arrive parfois en nombre JSON.
        #expect(food.barcode == "3033490004743")
        #expect(food.servingSizeInGrams == 125)
        #expect(food.nutritionPer100g.calories == 61)
        // La virgule décimale française est gérée.
        #expect(food.nutritionPer100g.proteins == 4.5)
        #expect(food.nutritionPer100g.carbohydrates == 5.5)
    }

    @Test("L'énergie en kilojoules est convertie en kilocalories")
    func convertsKilojoules() throws {
        let response = try decodeSearch(
            """
            {
              "products": [
                {
                  "code": "123",
                  "product_name": "Produit",
                  "nutriments": { "energy_100g": 1000, "proteins_100g": 5 }
                }
              ]
            }
            """
        )

        let food = try #require(response.products.first?.toRemoteFood())
        #expect(abs(food.nutritionPer100g.calories - 239.0) < 1)
    }

    @Test("L'énergie manquante est déduite des macros")
    func estimatesMissingEnergy() throws {
        let response = try decodeSearch(
            """
            {
              "products": [
                {
                  "code": "456",
                  "product_name": "Produit",
                  "nutriments": { "proteins_100g": 10, "carbohydrates_100g": 20, "fat_100g": 5 }
                }
              ]
            }
            """
        )

        let food = try #require(response.products.first?.toRemoteFood())
        #expect(food.nutritionPer100g.calories == 165)
    }

    @Test("Les produits inexploitables sont écartés")
    func dropsUnusableProducts() throws {
        let response = try decodeSearch(
            """
            {
              "products": [
                { "code": "1", "nutriments": { "energy-kcal_100g": 100 } },
                { "code": "2", "product_name": "Sans nutriments" },
                { "code": "3", "product_name": "Tout à zéro", "nutriments": { "proteins_100g": 0 } },
                { "product_name": "Sans code-barres", "nutriments": { "energy-kcal_100g": 50 } }
              ]
            }
            """
        )

        #expect(response.products.compactMap { $0.toRemoteFood() }.isEmpty)
    }

    @Test("Le nom français est préféré quand il existe")
    func prefersFrenchName() throws {
        let response = try decodeSearch(
            """
            {
              "products": [
                {
                  "code": "789",
                  "product_name": "Oat flakes",
                  "product_name_fr": "Flocons d'avoine",
                  "nutriments": { "energy-kcal_100g": 372 }
                }
              ]
            }
            """
        )

        #expect(response.products.first?.toRemoteFood()?.name == "Flocons d'avoine")
    }

    @Test("Une réponse produit absente renvoie nil")
    func decodesMissingProduct() throws {
        let response = try JSONDecoder().decode(
            OFFProductResponse.self,
            from: Data(#"{ "status": 0, "status_verbose": "product not found" }"#.utf8)
        )

        #expect(response.status == 0)
        #expect(response.product == nil)
    }
}

@Suite("Client Open Food Facts")
struct FoodDatabaseClientTests {
    @Test("Une recherche trop courte est refusée avant tout appel réseau")
    func rejectsShortQueries() async {
        let client = OpenFoodFactsClient()

        await #expect(throws: FoodDatabaseError.emptyQuery) {
            try await client.searchProducts(query: "a", page: 1)
        }
    }

    @Test("Un code-barres non numérique est refusé")
    func rejectsInvalidBarcode() async {
        let client = OpenFoodFactsClient()

        await #expect(throws: FoodDatabaseError.emptyQuery) {
            _ = try await client.product(barcode: "pas-un-code")
        }
    }

    @Test("Les erreurs réseau sont traduites pour l'interface")
    func mapsNetworkErrors() {
        #expect(FoodDatabaseError.from(URLError(.notConnectedToInternet)) == .offline)
        #expect(FoodDatabaseError.from(URLError(.timedOut)) == .timedOut)
        #expect(FoodDatabaseError.offline.errorDescription?.isEmpty == false)
    }

    @Test("Seules les pannes passagères sont réessayées")
    func classifiesRetryableErrors() {
        #expect(FoodDatabaseError.http(status: 503).isRetryable)
        #expect(FoodDatabaseError.http(status: 500).isRetryable)
        #expect(FoodDatabaseError.http(status: 429).isRetryable)
        #expect(FoodDatabaseError.timedOut.isRetryable)

        // Réessayer ne changerait rien à ces cas.
        #expect(!FoodDatabaseError.http(status: 404).isRetryable)
        #expect(!FoodDatabaseError.decoding.isRetryable)
        #expect(!FoodDatabaseError.emptyQuery.isRetryable)
        #expect(!FoodDatabaseError.invalidURL.isRetryable)
        #expect(!FoodDatabaseError.offline.isRetryable)
    }

    @Test("Une panne du moteur de recherche renvoie l'utilisateur vers le scanner")
    func explainsSearchOutage() throws {
        let message = try #require(FoodDatabaseError.http(status: 503).errorDescription)

        #expect(message.contains("code-barres"))
        #expect(try #require(FoodDatabaseError.http(status: 429).errorDescription).contains("Trop de requêtes"))
        // Les autres codes gardent le message générique, avec le numéro.
        #expect(try #require(FoodDatabaseError.http(status: 404).errorDescription).contains("404"))
    }
}
