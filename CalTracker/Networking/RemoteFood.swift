import Foundation

/// A product as returned by the remote database, before the user decides to
/// persist it. Keeping this separate from `FoodProduct` means search results
/// never touch SwiftData.
struct RemoteFood: Identifiable, Hashable, Sendable {
    let barcode: String
    let name: String
    let brand: String?
    let imageURLString: String?
    let servingSizeInGrams: Double?
    let nutritionPer100g: NutritionFacts

    var id: String { barcode }

    var imageURL: URL? {
        imageURLString.flatMap(URL.init(string:))
    }

    var displayName: String {
        guard let brand, !brand.isEmpty else { return name }
        return "\(name) — \(brand)"
    }
}

private enum EnergyConversion {
    static let kilojoulesPerKilocalorie = 4.184
}

extension OFFProduct {
    /// Maps the wire format to the domain type, dropping entries too incomplete
    /// to be logged (no name, or no nutrition at all).
    func toRemoteFood() -> RemoteFood? {
        guard let barcode = code?.trimmingCharacters(in: .whitespacesAndNewlines), !barcode.isEmpty else {
            return nil
        }

        let candidates = [productNameFR, productName, genericName]
        guard let name = candidates
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty })
        else { return nil }

        guard let nutriments, let facts = nutriments.toNutritionFacts() else { return nil }

        let brand = brands?
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return RemoteFood(
            barcode: barcode,
            name: name,
            brand: brand?.isEmpty == false ? brand : nil,
            imageURLString: imageThumbURL ?? imageURL,
            servingSizeInGrams: servingQuantity.flatMap { $0 > 0 ? $0 : nil },
            nutritionPer100g: facts
        )
    }
}

extension OFFSearchHit {
    /// Même contrat que `OFFProduct.toRemoteFood()` : une fiche sans nom ou
    /// sans nutriments exploitables n'atteint pas l'interface.
    func toRemoteFood() -> RemoteFood? {
        guard let barcode = code?.trimmingCharacters(in: .whitespacesAndNewlines), !barcode.isEmpty else {
            return nil
        }

        guard let name = [productName, genericName]
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty })
        else { return nil }

        guard let nutriments, let facts = nutriments.toNutritionFacts() else { return nil }

        return RemoteFood(
            barcode: barcode,
            name: name,
            // Les marques arrivent parfois en minuscules ("ferrero").
            brand: brands.first?.capitalizedFirstLetter,
            imageURLString: imageThumbURL ?? imageURL,
            servingSizeInGrams: servingQuantity.flatMap { $0 > 0 ? $0 : nil },
            nutritionPer100g: facts
        )
    }
}

extension OFFNutriments {
    /// `nil` when the contributor filled in nothing usable; a product with only
    /// zeros everywhere would otherwise show up as a valid 0 kcal food.
    func toNutritionFacts() -> NutritionFacts? {
        let proteins = proteins100g ?? 0
        let carbohydrates = carbohydrates100g ?? 0
        let fats = fat100g ?? 0

        let kilojoules = energyKjExplicit100g ?? energyKj100g
        var calories = energyKcal100g
            ?? kilojoules.map { $0 / EnergyConversion.kilojoulesPerKilocalorie }
            ?? 0
        let facts = NutritionFacts(
            calories: calories,
            proteins: proteins,
            carbohydrates: carbohydrates,
            fats: fats,
            fibers: fiber100g ?? 0,
            sugars: sugars100g ?? 0,
            saturatedFats: saturatedFat100g ?? 0,
            salt: salt100g ?? 0
        )

        let hasMacros = proteins > 0 || carbohydrates > 0 || fats > 0
        guard calories > 0 || hasMacros else { return nil }

        if calories <= 0 {
            calories = facts.estimatedCaloriesFromMacros
            var completed = facts
            completed.calories = calories
            return completed
        }
        return facts
    }
}
