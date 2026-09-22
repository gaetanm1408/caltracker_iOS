import Foundation

/// Shared number formatting so quantities and macros read the same everywhere.
enum QuantityFormatter {
    private static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    /// Drops the decimal part when it carries no information (250 g, not 250,0 g).
    static func string(from value: Double) -> String {
        decimal.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func grams(_ value: Double) -> String {
        "\(string(from: value)) g"
    }

    static func calories(_ value: Double) -> String {
        "\(Int(value.rounded())) kcal"
    }

    static func percentage(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }
}

extension Double {
    /// Parses user input accepting both `1.5` and `1,5`.
    static func parseUserInput(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}
