import Foundation

/// Sexe biologique, dont l'équation de Mifflin-St Jeor a besoin : à poids,
/// taille et âge égaux, le métabolisme de base diffère d'environ 166 kcal.
enum BiologicalSex: String, Codable, CaseIterable, Identifiable, Sendable {
    case female
    case male

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .female: return "Femme"
        case .male: return "Homme"
        }
    }

    /// Constante finale de l'équation de Mifflin-St Jeor.
    var basalOffset: Double {
        switch self {
        case .female: return -161
        case .male: return 5
        }
    }
}

/// Niveau d'activité quotidien, hors sport enregistré par une montre.
enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary
    case light
    case moderate
    case high
    case veryHigh

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .sedentary: return "Sédentaire"
        case .light: return "Légèrement actif"
        case .moderate: return "Modérément actif"
        case .high: return "Très actif"
        case .veryHigh: return "Extrêmement actif"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: return "Travail assis, peu ou pas d'exercice"
        case .light: return "Exercice léger 1 à 3 jours par semaine"
        case .moderate: return "Exercice modéré 3 à 5 jours par semaine"
        case .high: return "Exercice soutenu 6 à 7 jours par semaine"
        case .veryHigh: return "Travail physique ou double entraînement"
        }
    }

    /// Facteur appliqué au métabolisme de base pour obtenir la dépense totale.
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .high: return 1.725
        case .veryHigh: return 1.9
        }
    }
}

/// Direction que l'utilisateur donne à son alimentation.
enum WeightGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case deficit
    case maintenance
    case gain

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .deficit: return "Perte de poids"
        case .maintenance: return "Maintien"
        case .gain: return "Prise de masse"
        }
    }

    var detail: String {
        switch self {
        case .deficit: return "Environ −20 % de ta dépense, soit 0,5 kg par semaine"
        case .maintenance: return "Autant que tu dépenses"
        case .gain: return "Environ +12 %, pour limiter la prise de gras"
        }
    }

    /// Écart appliqué à la dépense totale, en proportion.
    var calorieAdjustment: Double {
        switch self {
        case .deficit: return -0.20
        case .maintenance: return 0
        case .gain: return 0.12
        }
    }

    /// Répartition des macros adaptée à l'objectif : davantage de protéines en
    /// déficit, où il s'agit de préserver la masse musculaire.
    var macroSplit: (protein: Double, carbohydrate: Double, fat: Double) {
        switch self {
        case .deficit: return (0.35, 0.35, 0.30)
        case .maintenance: return (0.30, 0.40, 0.30)
        case .gain: return (0.25, 0.45, 0.30)
        }
    }
}

/// Mesures corporelles nécessaires au calcul de la dépense énergétique.
struct BodyMeasurements: Equatable, Sendable {
    var weightInKilograms: Double
    var heightInCentimeters: Double
    var age: Int
    var sex: BiologicalSex

    /// Valeurs plausibles ; en dehors, le calcul n'a pas de sens et l'interface
    /// doit demander une correction plutôt qu'afficher un objectif fantaisiste.
    var isComplete: Bool {
        (20...300).contains(weightInKilograms)
            && (100...250).contains(heightInCentimeters)
            && (10...120).contains(age)
    }
}
