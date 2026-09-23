import Foundation
import SwiftData
import Testing

@testable import CalTracker

@Suite("Familles d'ingrédients")
struct IngredientFamilyTests {
    @Test("Chaque famille reconnaît ses aliments")
    func classifiesCommonIngredients() {
        let cases: [(String, IngredientFamily)] = [
            ("Blanc de poulet", .meat),
            ("Cuisse de poulet sans peau", .meat),
            ("Pavé de saumon", .seafood),
            ("Crevettes cuites décortiquées", .seafood),
            ("Œufs entiers", .dairyAndEggs),
            ("Yaourt grec 2 %", .dairyAndEggs),
            ("Lentilles vertes cuites", .legumes),
            ("Tofu ferme", .legumes),
            ("Riz basmati cuit", .starches),
            ("Pâtes complètes cuites", .starches),
            ("Myrtilles", .fruits),
            ("Amandes", .nutsAndSeeds),
            ("Épinards frais", .vegetables),
            ("Huile d'olive", .pantry)
        ]

        for (name, expected) in cases {
            #expect(
                IngredientFamily.of(name) == expected,
                "\(name) : \(IngredientFamily.of(name).localizedName) au lieu de \(expected.localizedName)"
            )
        }
    }

    @Test("Les noms trompeurs tombent du bon côté")
    func resistsMisleadingNames() {
        // Chacun de ces noms contient un mot-clé d'une autre famille : ce sont
        // eux qui cassent un classement naïf.
        let cases: [(String, IngredientFamily)] = [
            ("Pommes de terre", .starches),            // n'est pas un fruit
            ("Patate douce", .starches),
            ("Haricots verts", .vegetables),           // n'est pas une légumineuse
            ("Haricots rouges cuits", .legumes),
            ("Semoule de couscous cuite", .starches),  // contient « moule »
            ("Graines de courge", .nutsAndSeeds),      // n'est pas un légume
            ("Lait de coco allégé", .pantry),          // n'est pas un laitage
            ("Lait demi-écrémé", .dairyAndEggs),
            ("Blancs d'œufs", .dairyAndEggs),          // « blanc » n'est pas la volaille
            ("Fromage blanc 0 %", .dairyAndEggs),
            ("Jambon blanc", .meat),
            ("Sauce tomate", .pantry),                 // n'est pas un légume
            ("Tomates concassées", .pantry),
            ("Tomates cerises", .vegetables),
            ("Galettes de riz", .starches),
            ("Beurre de cacahuète", .nutsAndSeeds),    // n'est pas un laitage
            ("Poireau", .vegetables),                  // contient « poire »
            ("Laitue", .vegetables),                   // contient « lait »
            ("Chorizo", .meat)                         // contient « riz »
        ]

        for (name, expected) in cases {
            #expect(
                IngredientFamily.of(name) == expected,
                "\(name) : \(IngredientFamily.of(name).localizedName) au lieu de \(expected.localizedName)"
            )
        }
    }

    @Test("Accents, casse et pluriel ne changent rien")
    func ignoresSpellingVariations() {
        #expect(IngredientFamily.of("EPINARDS") == .vegetables)
        #expect(IngredientFamily.of("épinard") == .vegetables)
        #expect(IngredientFamily.of("Oeufs entiers") == .dairyAndEggs)
        #expect(IngredientFamily.of("œuf") == .dairyAndEggs)
    }

    @Test("Un aliment inconnu atterrit dans « Autres »")
    func fallsBackToOther() {
        #expect(IngredientFamily.of("Zwieback bavarois") == .other)
        #expect(IngredientFamily.of("") == .other)
    }
}

@MainActor
@Suite("Catalogue rangé par famille")
struct CatalogueIngredientFamilyTests {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
        _ = try RecipeCatalogueSeeder(context: context).seedIfNeeded(installedVersion: 0)
    }

    private func recipes() throws -> [Recipe] {
        try RecipeService(context: context).allRecipes()
    }

    @Test("Aucun ingrédient livré ne finit dans « Autres »")
    func classifiesEveryCatalogueIngredient() throws {
        let orphans = RecipeFilter.selectableIngredients(in: try recipes())
            .filter { IngredientFamily.of($0) == .other }

        #expect(orphans.isEmpty, "non classés : \(orphans.joined(separator: ", "))")
    }

    @Test("Le regroupement ne perd ni ne duplique personne")
    func groupsEveryIngredientExactlyOnce() throws {
        let all = RecipeFilter.selectableIngredients(in: try recipes())
        let groups = RecipeFilter.groupedSelectableIngredients(in: try recipes())
        let grouped = groups.flatMap(\.names)

        #expect(Set(grouped) == Set(all))
        #expect(grouped.count == all.count)
        #expect(!groups.contains { $0.names.isEmpty })
    }

    @Test("Les familles sortent dans l'ordre d'affichage")
    func respectsDisplayOrder() throws {
        let families = RecipeFilter.groupedSelectableIngredients(in: try recipes()).map(\.family)
        let expected = IngredientFamily.displayOrder.filter { families.contains($0) }

        #expect(families == expected)
        // Le catalogue couvre assez large pour remplir toutes les familles
        // nommées, « Autres » exceptée.
        #expect(Set(families) == Set(IngredientFamily.allCases).subtracting([.other]))
    }
}
