import Foundation
import SwiftData

/// Recettes livrées avec l'app, décrites dans `RecipeCatalogue.json`.
///
/// Le contenu vit dans une ressource plutôt que dans le code : ce sont des
/// données à relire et à corriger, pas de la logique.
struct RecipeCatalogue: Decodable {
    let version: Int
    let recipes: [CatalogueRecipe]

    static let resourceName = "RecipeCatalogue"

    static func load(from bundle: Bundle = .main) throws -> RecipeCatalogue {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(RecipeCatalogue.self, from: Data(contentsOf: url))
    }
}

struct CatalogueRecipe: Decodable {
    let name: String
    let summary: String
    let category: RecipeCategory
    let servings: Int
    let preparationMinutes: Int
    let instructions: String
    let equipment: [CookingEquipment]?
    let ingredients: [CatalogueIngredient]
}

struct CatalogueIngredient: Decodable {
    let name: String
    let quantity: Double
    let unit: MeasurementUnit
    let pantryStaple: Bool?
    let gramsPerPiece: Double?
    let per100g: NutritionFacts
}

/// Installe les recettes du catalogue qui manquent encore.
struct RecipeCatalogueSeeder {
    let context: ModelContext

    /// Ajoute les recettes absentes et renvoie la version installée.
    ///
    /// Le rapprochement se fait par nom : une recette supprimée ne revient pas
    /// tant que la version du catalogue ne change pas, et une version
    /// ultérieure n'installera que ses nouveautés.
    @discardableResult
    func seedIfNeeded(installedVersion: Int, bundle: Bundle = .main) throws -> Int {
        let catalogue = try RecipeCatalogue.load(from: bundle)
        guard catalogue.version > installedVersion else { return installedVersion }

        let existingNames = Set(try context.fetch(FetchDescriptor<Recipe>()).map(\.name))
        let service = RecipeService(context: context)

        for entry in catalogue.recipes where !existingNames.contains(entry.name) {
            let recipe = service.create(name: entry.name, servings: entry.servings)
            recipe.summary = entry.summary
            recipe.instructions = entry.instructions
            recipe.preparationMinutes = entry.preparationMinutes
            recipe.category = entry.category
            recipe.equipment = Set(entry.equipment ?? [])

            for ingredient in entry.ingredients {
                service.addIngredient(
                    to: recipe,
                    name: ingredient.name,
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    isPantryStaple: ingredient.pantryStaple ?? false,
                    gramsPerPiece: ingredient.gramsPerPiece,
                    nutritionPer100g: ingredient.per100g
                )
            }
        }
        return catalogue.version
    }
}
