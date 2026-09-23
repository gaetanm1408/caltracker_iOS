import Foundation
import SwiftData
import Testing

@testable import CalTracker

@MainActor
@Suite("Catalogue de recettes livré")
struct RecipeCatalogueTests {
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        container = try AppSchema.inMemoryContainer()
        context = container.mainContext
    }

    private func loadCatalogue() throws -> RecipeCatalogue {
        try RecipeCatalogue.load()
    }

    @Test("Le catalogue livré se décode")
    func decodesCatalogue() throws {
        let catalogue = try loadCatalogue()

        #expect(catalogue.version >= 1)
        #expect(!catalogue.recipes.isEmpty)
        #expect(catalogue.recipes.contains { $0.category == .meal })
        #expect(catalogue.recipes.contains { $0.category == .snack })
    }

    @Test("Chaque recette est cohérente")
    func describesUsableRecipes() throws {
        for recipe in try loadCatalogue().recipes {
            #expect(!recipe.name.isEmpty)
            #expect(recipe.servings >= 1)
            #expect(!recipe.ingredients.isEmpty, "\(recipe.name) n'a aucun ingrédient")

            for ingredient in recipe.ingredients {
                #expect(ingredient.quantity > 0, "\(recipe.name) / \(ingredient.name)")
                #expect(ingredient.per100g.calories > 0, "\(recipe.name) / \(ingredient.name)")
                // Une pièce sans poids unitaire n'apporterait aucune macro.
                if ingredient.unit.dimension == .count {
                    #expect(
                        (ingredient.gramsPerPiece ?? 0) > 0,
                        "\(recipe.name) / \(ingredient.name) : pièce sans poids unitaire"
                    )
                }
            }
        }
    }

    @Test("Toutes les recettes livrées sont réellement protéinées")
    func everyRecipeIsProteinRich() throws {
        let installed = try seed()

        for recipe in installed {
            let perServing = recipe.nutritionPerServing
            let share = NutritionCalculator.macroDistribution(in: perServing)[.proteins] ?? 0
            #expect(
                share >= 0.25,
                "\(recipe.name) : \(Int(share * 100)) % des calories en protéines"
            )
            #expect(perServing.calories > 0, "\(recipe.name) n'a aucun apport calculé")
        }
    }

    @Test("L'installation crée les recettes puis ne les duplique pas")
    func seedsOnceOnly() throws {
        let catalogue = try loadCatalogue()
        let seeder = RecipeCatalogueSeeder(context: context)

        let version = try seeder.seedIfNeeded(installedVersion: 0)
        #expect(version == catalogue.version)
        let firstCount = try RecipeService(context: context).allRecipes().count
        #expect(firstCount == catalogue.recipes.count)

        // Une version déjà installée ne réinstalle rien.
        _ = try seeder.seedIfNeeded(installedVersion: version)
        #expect(try RecipeService(context: context).allRecipes().count == firstCount)
    }

    @Test("Une recette supprimée ne revient pas")
    func doesNotRestoreDeletedRecipes() throws {
        let seeder = RecipeCatalogueSeeder(context: context)
        let version = try seeder.seedIfNeeded(installedVersion: 0)

        let service = RecipeService(context: context)
        let victim = try #require(try service.allRecipes().first)
        let name = victim.name
        service.delete(victim)

        _ = try seeder.seedIfNeeded(installedVersion: version)

        #expect(!(try service.allRecipes().contains { $0.name == name }))
    }

    @Test("Chaque combinaison calories × protéines laisse de quoi composer")
    func leavesAUsablePoolForEveryPlateCriteria() throws {
        let meals = try seed().filter { $0.category == .meal }

        for band in CalorieBand.allCases {
            for floor in ProteinFloor.allCases {
                var criteria = RecipeCriteria()
                criteria.calorieBand = band
                criteria.proteinFloor = floor
                let eligible = RecipeFilter.eligible(meals, matching: criteria)

                // Un filtre qui vide le vivier ne filtre plus : il bloque.
                #expect(
                    eligible.count >= 3,
                    "\(band.localizedName) + \(floor.localizedName) : \(eligible.count) repas"
                )
            }
        }
    }

    @Test("Un seul appareil suffit à composer un menu")
    func leavesAUsablePoolForEveryEquipment() throws {
        let meals = try seed().filter { $0.category == .meal }

        for equipment in CookingEquipment.allCases where !equipment.isAlwaysAvailable {
            var criteria = RecipeCriteria()
            criteria.availableEquipment = [equipment]
            let eligible = RecipeFilter.eligible(meals, matching: criteria)

            #expect(
                eligible.count >= 3,
                "\(equipment.localizedName) seul : \(eligible.count) repas"
            )
        }
    }

    @Test("Le catalogue couvre chaque matériel")
    func coversEveryPieceOfEquipment() throws {
        let declared = try loadCatalogue().recipes.reduce(into: Set<CookingEquipment>()) {
            $0.formUnion($1.equipment ?? [])
        }

        #expect(declared == Set(CookingEquipment.allCases))
    }

    private func seed() throws -> [Recipe] {
        _ = try RecipeCatalogueSeeder(context: context).seedIfNeeded(installedVersion: 0)
        return try RecipeService(context: context).allRecipes()
    }
}

@Suite("Ingrédients comptés à la pièce")
struct PieceIngredientTests {
    private let egg = NutritionFacts(calories: 143, proteins: 12.7, carbohydrates: 0.7, fats: 9.8)

    @Test("Un poids unitaire rend les macros calculables")
    func countsPiecesWithUnitWeight() {
        let ingredient = RecipeIngredient(
            name: "Œufs entiers",
            quantity: 2,
            unit: .piece,
            gramsPerPiece: 50,
            nutritionPer100g: egg
        )

        #expect(ingredient.quantityInGrams == 100)
        #expect(ingredient.nutritionContribution.calories == 143)
        #expect(abs(ingredient.nutritionContribution.proteins - 12.7) < 0.01)
    }

    @Test("Sans poids unitaire, une pièce n'apporte rien")
    func ignoresPiecesWithoutUnitWeight() {
        let ingredient = RecipeIngredient(
            name: "Tomates",
            quantity: 3,
            unit: .piece,
            nutritionPer100g: NutritionFacts(calories: 18, proteins: 0.9)
        )

        #expect(ingredient.quantityInGrams == nil)
        #expect(ingredient.nutritionContribution == .zero)
    }

    @Test("Le poids unitaire ne change rien aux unités de masse")
    func leavesMassUnitsAlone() {
        let ingredient = RecipeIngredient(
            name: "Poulet",
            quantity: 200,
            unit: .gram,
            gramsPerPiece: 999,
            nutritionPer100g: NutritionFacts(calories: 121, proteins: 25)
        )

        #expect(ingredient.quantityInGrams == 200)
        #expect(ingredient.nutritionContribution.calories == 242)
    }
}
