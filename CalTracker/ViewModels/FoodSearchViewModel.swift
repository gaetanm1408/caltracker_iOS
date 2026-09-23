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
    private(set) var selectedCategory: String?

    private var foundFoods: [RemoteFood] {
        if case .results(let foods) = state { return foods }
        return []
    }

    /// Catégories les plus représentées dans les résultats.
    ///
    /// Celles d'Open Food Facts sont hiérarchiques et verbeuses — un pot de
    /// pâte à tartiner en porte sept. Les plus fréquentes sont aussi les plus
    /// générales, donc celles qui découpent utilement une liste.
    var availableCategories: [String] {
        var counts: [String: Int] = [:]
        for food in foundFoods {
            for category in Set(food.categories) {
                counts[category, default: 0] += 1
            }
        }
        return counts
            // Une catégorie portée par un seul produit ne filtre rien d'utile.
            .filter { $0.value >= 2 }
            .sorted {
                $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
            }
            .prefix(8)
            .map(\.key)
    }

    var visibleResults: [RemoteFood] {
        guard let selectedCategory else { return foundFoods }
        return foundFoods.filter { $0.categories.contains(selectedCategory) }
    }

    func toggleCategory(_ category: String) {
        selectedCategory = selectedCategory == category ? nil : category
    }

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
        // Un filtre hérité de la recherche précédente masquerait les nouveaux
        // résultats sans que rien ne l'explique.
        selectedCategory = nil
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
