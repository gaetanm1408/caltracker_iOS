import Foundation

/// Wire format returned by the Open Food Facts search endpoint.
struct OFFSearchResponse: Decodable {
    let count: Int?
    let page: Int?
    let pageSize: Int?
    let products: [OFFProduct]

    enum CodingKeys: String, CodingKey {
        case count
        case page
        case pageSize = "page_size"
        case products
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decodeIfPresent(FlexibleNumber.self, forKey: .count)?.intValue
        page = try container.decodeIfPresent(FlexibleNumber.self, forKey: .page)?.intValue
        pageSize = try container.decodeIfPresent(FlexibleNumber.self, forKey: .pageSize)?.intValue
        products = try container.decodeIfPresent([OFFProduct].self, forKey: .products) ?? []
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
