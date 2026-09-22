import Foundation

/// Abstraction over the remote food database so the search feature can be
/// driven by a stub in tests and previews.
protocol FoodDatabaseClient: Sendable {
    func searchProducts(query: String, page: Int) async throws -> [RemoteFood]
    func product(barcode: String) async throws -> RemoteFood?
}

enum FoodDatabaseError: LocalizedError, Equatable {
    case emptyQuery
    case invalidURL
    case http(status: Int)
    case decoding
    case offline
    case timedOut

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Saisis au moins deux caractères pour lancer la recherche."
        case .invalidURL:
            return "La requête envoyée à Open Food Facts est invalide."
        case .http(let status) where (500..<600).contains(status):
            // Le moteur de recherche plein texte d'Open Food Facts tombe
            // régulièrement, alors que la recherche par code-barres tient.
            return "Le service de recherche d'Open Food Facts est momentanément indisponible. Le scan de code-barres, lui, fonctionne toujours."
        case .http(status: 429):
            return "Trop de requêtes envoyées à Open Food Facts. Patiente quelques instants."
        case .http(let status):
            return "Open Food Facts a répondu avec une erreur (code \(status))."
        case .decoding:
            return "La réponse d'Open Food Facts n'a pas pu être lue."
        case .offline:
            return "Aucune connexion internet. Vérifie ton réseau puis réessaie."
        case .timedOut:
            return "Open Food Facts met trop de temps à répondre. Réessaie."
        }
    }

    /// Pannes passagères, qui méritent une nouvelle tentative. Une requête
    /// malformée ou une réponse illisible échoueraient à l'identique.
    var isRetryable: Bool {
        switch self {
        case .http(let status):
            return status == 429 || (500..<600).contains(status)
        case .timedOut:
            return true
        case .emptyQuery, .invalidURL, .decoding, .offline:
            return false
        }
    }

    /// Maps URLSession failures onto the cases the UI knows how to present.
    static func from(_ error: Error) -> FoodDatabaseError {
        guard let urlError = error as? URLError else { return .decoding }
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed, .networkConnectionLost:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .http(status: urlError.errorCode)
        }
    }
}
