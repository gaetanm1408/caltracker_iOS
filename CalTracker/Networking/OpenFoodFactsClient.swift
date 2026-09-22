import Foundation

/// Talks to the public Open Food Facts REST API.
///
/// Deux services distincts : la recherche plein texte passe par
/// `search.openfoodfacts.org`, le remplaçant de `cgi/search.pl` dont les
/// pannes rendaient la recherche inutilisable ; la consultation par
/// code-barres reste sur l'API produit historique.
///
/// Open Food Facts asks every client to identify itself with a descriptive
/// User-Agent; requests without one are throttled.
final class OpenFoodFactsClient: FoodDatabaseClient {
    private let session: URLSession
    private let baseURL: URL
    private let searchBaseURL: URL
    private let userAgent: String
    private let pageSize: Int
    private let maxAttempts: Int

    /// Only the fields the app actually reads, which keeps responses small.
    private static let productFields = [
        "code",
        "product_name",
        "product_name_fr",
        "generic_name",
        "brands",
        "serving_quantity",
        "image_url",
        "image_front_small_url",
        "nutriments"
    ].joined(separator: ",")

    /// Le service de recherche n'expose pas les mêmes champs que l'API produit.
    private static let searchFields = [
        "code",
        "product_name",
        "generic_name",
        "brands",
        "serving_quantity",
        "image_url",
        "nutriments"
    ].joined(separator: ",")

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org")!,
        searchBaseURL: URL = URL(string: "https://search.openfoodfacts.org")!,
        // Open Food Facts limite le débit des clients qui ne s'identifient pas.
        // L'URL du dépôt sert de point de contact sans exposer d'adresse
        // personnelle dans un dépôt public.
        userAgent: String = "CalTracker/1.0 (iOS; +https://github.com/gaetanm1408/caltracker_iOS)",
        pageSize: Int = 25,
        maxAttempts: Int = 3
    ) {
        self.session = session
        self.baseURL = baseURL
        self.searchBaseURL = searchBaseURL
        self.userAgent = userAgent
        self.pageSize = pageSize
        self.maxAttempts = max(1, maxAttempts)
    }

    func searchProducts(query: String, page: Int) async throws -> [RemoteFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw FoodDatabaseError.emptyQuery }

        var components = URLComponents(
            url: searchBaseURL.appendingPathComponent("search"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "fields", value: Self.searchFields)
        ]
        guard let url = components?.url else { throw FoodDatabaseError.invalidURL }

        let response: OFFSearchHitsResponse = try await fetch(url)
        return response.hits.compactMap { $0.toRemoteFood() }
    }

    func product(barcode: String) async throws -> RemoteFood? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) else {
            throw FoodDatabaseError.emptyQuery
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v2/product/\(trimmed).json"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "fields", value: Self.productFields)]
        guard let url = components?.url else { throw FoodDatabaseError.invalidURL }

        let response: OFFProductResponse = try await fetch(url)
        guard response.status == 1 else { return nil }
        return response.product?.toRemoteFood()
    }

    /// Réessaie les pannes passagères avec une attente doublée à chaque tour.
    /// Un 503 revient immédiatement, donc le coût réel se limite à l'attente.
    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        for attempt in 1...maxAttempts {
            do {
                return try await performRequest(url)
            } catch let error as FoodDatabaseError {
                guard error.isRetryable, attempt < maxAttempts else { throw error }
                try await Task.sleep(for: .seconds(pow(2, Double(attempt - 1))))
            }
        }
        throw FoodDatabaseError.timedOut
    }

    private func performRequest<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FoodDatabaseError.from(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FoodDatabaseError.http(status: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw FoodDatabaseError.decoding
        }
    }
}
