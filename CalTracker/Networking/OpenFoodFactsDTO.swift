import Foundation

/// Wire format of the modern full-text search service
/// (`search.openfoodfacts.org`), which replaces the chronically overloaded
/// `cgi/search.pl`. Results live under `hits`, and `nutriments` carries the
/// same field names as the historical API.
struct OFFSearchHitsResponse: Decodable {
    let hits: [OFFSearchHit]
    let count: Int?
    let page: Int?

    enum CodingKeys: String, CodingKey {
        case hits
        case count
        case page
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hits = try container.decodeIfPresent([OFFSearchHit].self, forKey: .hits) ?? []
        count = try container.decodeIfPresent(FlexibleNumber.self, forKey: .count)?.intValue
        page = try container.decodeIfPresent(FlexibleNumber.self, forKey: .page)?.intValue
    }
}

struct OFFSearchHit: Decodable {
    let code: String?
    let productName: String?
    let genericName: String?
    let brands: [String]
    let imageURL: String?
    let servingQuantity: Double?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case genericName = "generic_name"
        case brands
        case imageURL = "image_url"
        case servingQuantity = "serving_quantity"
        case nutriments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(FlexibleNumber.self, forKey: .code)?.stringValue
        productName = try container.decodeIfPresent(LocalizedText.self, forKey: .productName)?.value
        genericName = try container.decodeIfPresent(LocalizedText.self, forKey: .genericName)?.value
        brands = try container.decodeIfPresent(FlexibleStringList.self, forKey: .brands)?.values ?? []
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        servingQuantity = try container.decodeIfPresent(FlexibleNumber.self, forKey: .servingQuantity)?.doubleValue
        nutriments = try container.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
    }
}

/// `product_name` arrives flat when the request projects it through `fields`,
/// but the index stores one entry per language; both shapes are accepted.
struct LocalizedText: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            value = text
        } else if let byLanguage = try? container.decode([String: String].self) {
            let candidates = byLanguage.filter { !$0.value.isEmpty }
            // Tri alphabétique sur la langue à défaut de français ou d'anglais,
            // pour que deux exécutions retiennent le même libellé.
            value = candidates["fr"] ?? candidates["en"]
                ?? candidates.sorted { $0.key < $1.key }.first?.value
        } else {
            value = nil
        }
    }
}

/// `brands` est un tableau sur le service de recherche, une chaîne séparée par
/// des virgules sur l'API historique.
struct FlexibleStringList: Decodable {
    let values: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([String].self) {
            values = list.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        } else if let joined = try? container.decode(String.self) {
            values = joined
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            values = []
        }
    }
}

/// Wire format returned by the single-product (barcode) endpoint.
struct OFFProductResponse: Decodable {
    let status: Int?
    let product: OFFProduct?

    enum CodingKeys: String, CodingKey {
        case status
        case product
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(FlexibleNumber.self, forKey: .status)?.intValue
        product = try container.decodeIfPresent(OFFProduct.self, forKey: .product)
    }
}

struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let productNameFR: String?
    let genericName: String?
    let brands: String?
    let servingQuantity: Double?
    let imageURL: String?
    let imageThumbURL: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameFR = "product_name_fr"
        case genericName = "generic_name"
        case brands
        case servingQuantity = "serving_quantity"
        case imageURL = "image_url"
        case imageThumbURL = "image_front_small_url"
        case nutriments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(FlexibleNumber.self, forKey: .code)?.stringValue
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        productNameFR = try container.decodeIfPresent(String.self, forKey: .productNameFR)
        genericName = try container.decodeIfPresent(String.self, forKey: .genericName)
        brands = try container.decodeIfPresent(String.self, forKey: .brands)
        servingQuantity = try container.decodeIfPresent(FlexibleNumber.self, forKey: .servingQuantity)?.doubleValue
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        imageThumbURL = try container.decodeIfPresent(String.self, forKey: .imageThumbURL)
        nutriments = try container.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
    }
}

struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let energyKj100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let saturatedFat100g: Double?
    let salt100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKj100g = "energy_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case salt100g = "salt_100g"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value(_ key: CodingKeys) throws -> Double? {
            try container.decodeIfPresent(FlexibleNumber.self, forKey: key)?.doubleValue
        }
        energyKcal100g = try value(.energyKcal100g)
        energyKj100g = try value(.energyKj100g)
        proteins100g = try value(.proteins100g)
        carbohydrates100g = try value(.carbohydrates100g)
        fat100g = try value(.fat100g)
        fiber100g = try value(.fiber100g)
        sugars100g = try value(.sugars100g)
        saturatedFat100g = try value(.saturatedFat100g)
        salt100g = try value(.salt100g)
    }
}

/// Open Food Facts is crowd-sourced and returns the same field sometimes as a
/// number, sometimes as a string; this decodes either shape.
struct FlexibleNumber: Decodable {
    let doubleValue: Double?
    let stringValue: String?

    var intValue: Int? { doubleValue.map { Int($0) } }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            doubleValue = double
            stringValue = double == double.rounded() ? String(Int(double)) : String(double)
        } else if let string = try? container.decode(String.self) {
            stringValue = string
            doubleValue = Double(string.replacingOccurrences(of: ",", with: "."))
        } else {
            doubleValue = nil
            stringValue = nil
        }
    }
}
