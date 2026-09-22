import Foundation
import SwiftData

/// Owns the local catalogue of products: imports from Open Food Facts, custom
/// foods, and the "recently used" list.
struct ProductRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Returns the stored product for a remote result, creating it on first
    /// import and refreshing its nutrition afterwards.
    @discardableResult
    func importProduct(from remote: RemoteFood) throws -> FoodProduct {
        if let existing = try product(withBarcode: remote.barcode) {
            existing.name = remote.name
            existing.brand = remote.brand
            existing.imageURLString = remote.imageURLString
            existing.servingSizeInGrams = remote.servingSizeInGrams
            existing.nutritionPer100g = remote.nutritionPer100g
            return existing
        }

        let product = FoodProduct(
            barcode: remote.barcode,
            name: remote.name,
            brand: remote.brand,
            imageURLString: remote.imageURLString,
            servingSizeInGrams: remote.servingSizeInGrams,
            nutritionPer100g: remote.nutritionPer100g
        )
        context.insert(product)
        return product
    }

    func product(withBarcode barcode: String) throws -> FoodProduct? {
        var descriptor = FetchDescriptor<FoodProduct>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Products already logged at least once, most recent first.
    func recentlyUsed(limit: Int = 20) throws -> [FoodProduct] {
        var descriptor = FetchDescriptor<FoodProduct>(
            predicate: #Predicate { $0.lastUsedAt != nil },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
}
