import Foundation

/// Units accepted for recipe ingredients and shopping list rows.
///
/// Each unit belongs to a dimension; quantities are only merged together when
/// they share a dimension, which is what makes shopping list aggregation safe.
enum MeasurementUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case gram = "g"
    case kilogram = "kg"
    case milliliter = "ml"
    case liter = "l"
    case piece = "pièce"
    case tablespoon = "c. à soupe"
    case teaspoon = "c. à café"

    var id: String { rawValue }

    enum Dimension: String, Sendable {
        case mass
        case volume
        case count
    }

    var dimension: Dimension {
        switch self {
        case .gram, .kilogram: return .mass
        case .milliliter, .liter, .tablespoon, .teaspoon: return .volume
        case .piece: return .count
        }
    }

    /// Quantity of the dimension's base unit (gram, milliliter or piece)
    /// represented by one unit of the receiver.
    var baseUnitFactor: Double {
        switch self {
        case .gram, .milliliter, .piece: return 1
        case .kilogram, .liter: return 1000
        case .tablespoon: return 15
        case .teaspoon: return 5
        }
    }

    var displayName: String { rawValue }

    /// Picks the most readable unit for a quantity expressed in the base unit,
    /// so 1500 g is displayed as 1,5 kg rather than 1500 g.
    static func preferredUnit(forBaseQuantity quantity: Double, dimension: Dimension) -> MeasurementUnit {
        switch dimension {
        case .mass:
            return quantity >= 1000 ? .kilogram : .gram
        case .volume:
            return quantity >= 1000 ? .liter : .milliliter
        case .count:
            return .piece
        }
    }
}
