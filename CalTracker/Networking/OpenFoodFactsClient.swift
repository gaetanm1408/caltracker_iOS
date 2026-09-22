import Foundation

/// Talks to the public Open Food Facts REST API.
///
/// Open Food Facts asks every client to identify itself with a descriptive
/// User-Agent; requests without one are throttled.
final class OpenFoodFactsClient: FoodDatabaseClient {
    private let session: URLSession
    private let baseURL: URL
    private let userAgent: String
    private let pageSize: Int

    /// Only the fields the app actually reads, which keeps responses small.
    private static let requestedFields = [
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

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org")!,
        userAgent: String = "CalTracker/1.0 (iOS; contact@caltracker.app)",
        pageSize: Int = 25
    ) {
        self.session = session
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.pageSize = pageSize
    }

    func searchProducts(query: String, page: Int) async throws -> [RemoteFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw FoodDatabaseError.emptyQuery }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("cgi/search.pl"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "fields", value: Self.requestedFields)
        ]
        guard let url = components?.url else { throw FoodDatabaseError.invalidURL }

        let response: OFFSearchResponse = try await fetch(url)
        return response.products.compactMap { $0.toRemoteFood() }
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
        components?.queryItems = [URLQueryItem(name: "fields", value: Self.requestedFields)]
        guard let url = components?.url else { throw FoodDatabaseError.invalidURL }

        let response: OFFProductResponse = try await fetch(url)
        guard response.status == 1 else { return nil }
        return response.product?.toRemoteFood()
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
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
