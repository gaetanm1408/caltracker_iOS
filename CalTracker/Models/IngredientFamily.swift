import Foundation

/// Famille d'un ingrédient, pour ranger la liste des aliments qu'on peut
/// écarter.
///
/// Déduite du nom plutôt que stockée : les recettes saisies à la main comptent
/// autant que celles du catalogue, et rien ne les obligerait à porter une
/// étiquette.
enum IngredientFamily: String, CaseIterable, Identifiable, Sendable {
    case vegetables
    case meat
    case seafood
    case dairyAndEggs
    case legumes
    case starches
    case fruits
    case nutsAndSeeds
    case pantry
    case other

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .vegetables: return "Légumes"
        case .meat: return "Viandes et volailles"
        case .seafood: return "Produits de la mer"
        case .dairyAndEggs: return "Œufs et laitages"
        case .legumes: return "Légumineuses et soja"
        case .starches: return "Féculents et céréales"
        case .fruits: return "Fruits"
        case .nutsAndSeeds: return "Oléagineux et graines"
        case .pantry: return "Épicerie"
        case .other: return "Autres"
        }
    }

    var systemImageName: String {
        switch self {
        case .vegetables: return "carrot"
        case .meat: return "fork.knife"
        case .seafood: return "fish"
        case .dairyAndEggs: return "oval.portrait"
        case .legumes: return "circle.grid.2x2"
        case .starches: return "laurel.leading"
        case .fruits: return "apple.logo"
        case .nutsAndSeeds: return "leaf"
        case .pantry: return "cabinet"
        case .other: return "questionmark.circle"
        }
    }

    /// Ordre d'affichage : ce qu'on écarte le plus souvent vient en premier.
    static let displayOrder: [IngredientFamily] = [
        .vegetables, .meat, .seafood, .dairyAndEggs,
        .legumes, .starches, .fruits, .nutsAndSeeds, .pantry, .other
    ]

    /// La famille d'un aliment, `.other` quand rien ne la trahit.
    static func of(_ ingredientName: String) -> IngredientFamily {
        let name = normalize(ingredientName)
        guard !name.isEmpty else { return .other }
        return normalizedRules.first { name.contains($0.keyword) }?.family ?? .other
    }

    /// Mots-clés confrontés au nom, premier trouvé l'emporte.
    ///
    /// Écrits en français lisible : ils subissent la même normalisation que les
    /// noms d'ingrédients, donc « haricot vert » reconnaît « Haricots verts ».
    private static let rules: [(keyword: String, family: IngredientFamily)] = [
        // Les pièges d'abord — chacun serait avalé par une règle plus bas.
        ("semoule", .starches),             // contient « moule »
        ("poireau", .vegetables),           // contient « poire »
        ("laitue", .vegetables),            // contient « lait »
        ("chorizo", .meat),                 // contient « riz »
        ("pomme de terre", .starches),      // n'est pas une pomme
        ("patate douce", .starches),
        ("haricot vert", .vegetables),      // n'est pas une légumineuse
        ("petit pois", .vegetables),
        ("pois chiche", .legumes),
        ("tomate cerise", .vegetables),
        ("sauce tomate", .pantry),
        ("tomate concassée", .pantry),
        ("lait de coco", .pantry),
        ("sauce soja", .pantry),
        ("beurre de cacahuète", .nutsAndSeeds),
        ("galette de riz", .starches),
        ("blanc de poulet", .meat),
        ("blanc de dinde", .meat),
        ("blanc d'œuf", .dairyAndEggs),
        ("fromage blanc", .dairyAndEggs),

        // Produits de la mer.
        ("saumon", .seafood), ("thon", .seafood), ("cabillaud", .seafood),
        ("colin", .seafood), ("merlu", .seafood), ("crevette", .seafood),
        ("poisson", .seafood), ("sardine", .seafood), ("maquereau", .seafood),
        ("truite", .seafood), ("calamar", .seafood), ("surimi", .seafood),

        // Viandes et volailles.
        ("poulet", .meat), ("dinde", .meat), ("bœuf", .meat), ("porc", .meat),
        ("jambon", .meat), ("steak", .meat), ("paleron", .meat), ("agneau", .meat),
        ("veau", .meat), ("canard", .meat), ("lardon", .meat), ("saucisse", .meat),
        ("bacon", .meat), ("viande", .meat),

        // Œufs et laitages.
        ("œuf", .dairyAndEggs), ("yaourt", .dairyAndEggs), ("skyr", .dairyAndEggs),
        ("cottage", .dairyAndEggs), ("feta", .dairyAndEggs), ("mozzarella", .dairyAndEggs),
        ("parmesan", .dairyAndEggs), ("emmental", .dairyAndEggs), ("comté", .dairyAndEggs),
        ("ricotta", .dairyAndEggs), ("fromage", .dairyAndEggs), ("crème", .dairyAndEggs),
        ("lait", .dairyAndEggs), ("beurre", .dairyAndEggs),

        // Légumineuses et soja.
        ("lentille", .legumes), ("haricot", .legumes), ("édamame", .legumes),
        ("tofu", .legumes), ("houmous", .legumes), ("fève", .legumes),

        // Oléagineux et graines — avant les légumes, pour les graines de courge.
        ("amande", .nutsAndSeeds), ("noisette", .nutsAndSeeds), ("noix", .nutsAndSeeds),
        ("cajou", .nutsAndSeeds), ("pistache", .nutsAndSeeds), ("graine", .nutsAndSeeds),
        ("cacahuète", .nutsAndSeeds), ("chia", .nutsAndSeeds), ("tournesol", .nutsAndSeeds),
        ("sésame", .nutsAndSeeds),

        // Légumes.
        ("brocoli", .vegetables), ("carotte", .vegetables), ("champignon", .vegetables),
        ("concombre", .vegetables), ("courgette", .vegetables), ("épinard", .vegetables),
        ("oignon", .vegetables), ("poivron", .vegetables), ("roquette", .vegetables),
        ("salade", .vegetables), ("avocat", .vegetables), ("maïs", .vegetables),
        ("aubergine", .vegetables), ("chou", .vegetables), ("betterave", .vegetables),
        ("asperge", .vegetables), ("fenouil", .vegetables), ("potiron", .vegetables),
        ("navet", .vegetables), ("céleri", .vegetables), ("radis", .vegetables),
        ("tomate", .vegetables),

        // Féculents et céréales.
        ("riz", .starches), ("pâtes", .starches), ("pain", .starches),
        ("couscous", .starches), ("boulgour", .starches), ("quinoa", .starches),
        ("avoine", .starches), ("flocon", .starches), ("tortilla", .starches),
        ("nouille", .starches), ("galette", .starches), ("polenta", .starches),

        // Fruits.
        ("ananas", .fruits), ("banane", .fruits), ("fraise", .fruits),
        ("framboise", .fruits), ("mangue", .fruits), ("myrtille", .fruits),
        ("pomme", .fruits), ("poire", .fruits), ("orange", .fruits),
        ("kiwi", .fruits), ("raisin", .fruits), ("pêche", .fruits),
        ("abricot", .fruits), ("citron", .fruits), ("datte", .fruits),

        // Épicerie.
        ("huile", .pantry), ("miel", .pantry), ("sirop", .pantry),
        ("cacao", .pantry), ("chocolat", .pantry), ("whey", .pantry),
        ("protéine", .pantry), ("sauce", .pantry), ("vinaigre", .pantry),
        ("chapelure", .pantry), ("moutarde", .pantry), ("bouillon", .pantry),
        ("confiture", .pantry), ("épice", .pantry)
    ]

    private static let normalizedRules: [(keyword: String, family: IngredientFamily)] =
        rules.map { (normalize($0.keyword), $0.family) }

    /// Nom réduit à ses mots au singulier, sans accent ni casse.
    ///
    /// Les mots-clés y passent aussi, ce qui garde la table lisible : c'est le
    /// même traitement des deux côtés, donc les deux se rencontrent.
    private static func normalize(_ name: String) -> String {
        let folded = name
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "Œ", with: "OE")
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "fr_FR"))
        return folded
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { word -> String in
                // Un mot trop court n'a plus de sens amputé : « pois » ne doit
                // pas devenir « poi », ni « maïs » « mai ».
                guard word.count > 4, word.hasSuffix("s") || word.hasSuffix("x") else {
                    return String(word)
                }
                return String(word.dropLast())
            }
            .joined(separator: " ")
    }
}

/// Les aliments d'une même famille, tels que l'écran de sélection les range.
struct IngredientGroup: Identifiable, Sendable {
    let family: IngredientFamily
    let names: [String]

    var id: String { family.rawValue }
}
