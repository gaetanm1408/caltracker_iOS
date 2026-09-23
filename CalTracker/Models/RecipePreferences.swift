import Foundation

/// Fourchette de calories visée pour une assiette.
///
/// Ne s'applique qu'aux repas : une collation tourne autour de 250 kcal, et lui
/// imposer la même fourchette reviendrait à toutes les écarter.
enum CalorieBand: String, Codable, CaseIterable, Identifiable, Sendable {
    case any
    case light
    case balanced
    case hearty

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .any: return "Peu importe"
        case .light: return "Léger"
        case .balanced: return "Équilibré"
        case .hearty: return "Costaud"
        }
    }

    var detail: String? {
        switch self {
        case .any: return nil
        case .light: return "400 à 600 kcal"
        case .balanced: return "600 à 800 kcal"
        case .hearty: return "plus de 800 kcal"
        }
    }

    func accepts(_ caloriesPerServing: Double) -> Bool {
        switch self {
        case .any: return true
        case .light: return (400...600).contains(caloriesPerServing)
        case .balanced: return (600...800).contains(caloriesPerServing)
        case .hearty: return caloriesPerServing > 800
        }
    }
}

/// Plancher de protéines par assiette, pour les repas.
enum ProteinFloor: String, Codable, CaseIterable, Identifiable, Sendable {
    case any
    case thirty
    case forty
    case fifty

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .any: return "Au pif"
        case .thirty: return "+ 30 g"
        case .forty: return "+ 40 g"
        case .fifty: return "+ 50 g"
        }
    }

    var grams: Double? {
        switch self {
        case .any: return nil
        case .thirty: return 30
        case .forty: return 40
        case .fifty: return 50
        }
    }

    func accepts(_ proteinsPerServing: Double) -> Bool {
        guard let grams else { return true }
        return proteinsPerServing >= grams
    }
}

/// Matériel qu'une recette réclame.
enum CookingEquipment: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Ni cuisson ni appareil : on assemble.
    case none
    case stovetop
    case oven
    case airFryer

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .none: return "Sans cuisson"
        case .stovetop: return "Plaque"
        case .oven: return "Four"
        case .airFryer: return "Air fryer"
        }
    }

    var systemImageName: String {
        switch self {
        case .none: return "leaf"
        case .stovetop: return "flame"
        case .oven: return "oven"
        case .airFryer: return "wind"
        }
    }

    /// Une recette sans cuisson est toujours réalisable.
    var isAlwaysAvailable: Bool { self == .none }
}
