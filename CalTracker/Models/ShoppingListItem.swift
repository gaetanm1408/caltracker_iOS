import Foundation
import SwiftData

/// A row of the shopping list, possibly aggregating the same ingredient coming
/// from several recipes.
@Model
final class ShoppingListItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double
    var unitRawValue: String
    var isChecked: Bool
    var createdAt: Date
    var sortIndex: Int
    /// Names of the recipes this row was generated from, so the user can see
    /// why an item is on the list.
    var sourceRecipeNames: [String]
    var isManuallyAdded: Bool

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        isChecked: Bool = false,
        createdAt: Date = .now,
        sortIndex: Int = 0,
        sourceRecipeNames: [String] = [],
        isManuallyAdded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitRawValue = unit.rawValue
        self.isChecked = isChecked
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.sourceRecipeNames = sourceRecipeNames
        self.isManuallyAdded = isManuallyAdded
    }

    var unit: MeasurementUnit {
        get { MeasurementUnit(rawValue: unitRawValue) ?? .gram }
        set { unitRawValue = newValue.rawValue }
    }

    var quantityDescription: String {
        "\(QuantityFormatter.string(from: quantity)) \(unit.displayName)"
    }

    var originDescription: String? {
        guard !sourceRecipeNames.isEmpty else { return nil }
        return sourceRecipeNames.joined(separator: ", ")
    }
}
