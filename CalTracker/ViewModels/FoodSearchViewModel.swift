import Foundation
import Observation

/// Drives the Open Food Facts search screen: debouncing, cancellation and the
/// state the view renders.
@MainActor
@Observable
final class FoodSearchViewModel {
    enum State: Equatable {
        case idle
        case searching
        case results([RemoteFood])
        case empty(query: String)
        case failed(message: String)
    }

    private(set) var query: String = ""
    private(set) var state: State = .idle

    private let client: FoodDatabaseClient
    private let debounce: Duration
    private var searchTask: Task<Void, Never>?

    init(client: FoodDatabaseClient, debounce: Duration = .milliseconds(350)) {
        self.client = client
        self.debounce = debounce
    }

    /// Called on every keystroke from the search field.
    func updateQuery(_ newValue: String) {
        guard newValue != query else { return }
        query = newValue
        scheduleSearch()
    }

    /// Restarts the debounce timer; every keystroke cancels the in-flight request.
    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else {
            state = .idle
            return
        }

        let delay = debounce
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.performSearch(trimmed)
        }
    }

    /// Runs a search immediately, bypassing the debounce (submit button, retry).
    func searchNow() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            state = .idle
            return
        }
        searchTask = Task { [weak self] in
            await self?.performSearch(trimmed)
        }
    }

    private func performSearch(_ trimmed: String) async {
        state = .searching
        do {
            let foods = try await client.searchProducts(query: trimmed, page: 1)
            guard !Task.isCancelled else { return }
            state = foods.isEmpty ? .empty(query: trimmed) : .results(foods)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            let message = (error as? LocalizedError)?.errorDescription
                ?? "La recherche a échoué. Réessaie dans un instant."
            state = .failed(message: message)
        }
    }

    /// Looks a scanned barcode up. Returns the product so the caller can open
    /// the logging sheet straight away; the state carries the failure otherwise.
    func lookup(barcode: String) async -> RemoteFood? {
        searchTask?.cancel()
        state = .searching
        do {
            guard let food = try await client.product(barcode: barcode) else {
                state = .empty(query: barcode)
                return nil
            }
            query = food.name
            state = .results([food])
            return food
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Aucun produit ne correspond à ce code-barres."
            state = .failed(message: message)
            return nil
        }
    }
}
