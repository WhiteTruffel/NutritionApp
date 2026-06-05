import Foundation

struct OFFEnvelope: Decodable {
    let status: Int
    let product: OFFProduct?
}

/// Antwort der Namenssuche (cgi/search.pl, veraltet): Liste statt Einzelprodukt.
struct OFFSearchEnvelope: Decodable {
    let products: [OFFProduct]
}

/// Antwort der modernen Volltextsuche (search.openfoodfacts.org): Treffer unter `hits`.
struct OFFSearchHitsEnvelope: Decodable {
    let hits: [OFFProduct]
}

struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantity: String?   // Gramm der Portion – OFF liefert mal String ("20.7"), mal Zahl (330)
    let nutritionDataPer: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutritionDataPer = "nutrition_data_per"
        case nutriments
    }

    // OFF ist beim Typ inkonsistent: `serving_quantity` kommt teils als JSON-Zahl,
    // teils als String. Mit dem synthetisierten Decoder würde eine Zahl hier den
    // gesamten Produkt-Decode werfen → Produkt fälschlich „nicht gefunden". Darum
    // alle wackeligen Felder einzeln und tolerant lesen (fehlend/falscher Typ → nil).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code             = try? c.decodeIfPresent(String.self, forKey: .code)
        productName      = try? c.decodeIfPresent(String.self, forKey: .productName)
        servingSize      = try? c.decodeIfPresent(String.self, forKey: .servingSize)
        // brands: Produkt-API liefert String ("Corny, Schwartau"), die Volltextsuche
        // ein Array (["Corny"]). Beides akzeptieren und als String ablegen.
        if let s = try? c.decode(String.self, forKey: .brands) {
            brands = s
        } else if let arr = try? c.decode([String].self, forKey: .brands) {
            brands = arr.joined(separator: ", ")
        } else {
            brands = nil
        }
        nutritionDataPer = try? c.decodeIfPresent(String.self, forKey: .nutritionDataPer)
        nutriments       = try? c.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
        // serving_quantity: String ODER Zahl akzeptieren, immer als String ablegen.
        if let s = try? c.decode(String.self, forKey: .servingQuantity) {
            servingQuantity = s
        } else if let d = try? c.decode(Double.self, forKey: .servingQuantity) {
            servingQuantity = String(d)
        } else {
            servingQuantity = nil
        }
    }

    /// Portionsgröße in Gramm: bevorzugt `serving_quantity`, sonst Zahl vor „g" aus
    /// `serving_size` (z. B. „41.5 g" → 41,5; „1 bar (21 g)" → 21). Nur plausible Werte.
    var servingSizeGrams: Double? {
        if let q = servingQuantity?.replacingOccurrences(of: ",", with: "."),
           let g = Double(q), g > 0, g < 2000 { return g }
        if let s = servingSize {
            // letzte Zahl, die von optionalem Leerzeichen + „g/ml" gefolgt wird
            let pattern = "([0-9]+(?:[.,][0-9]+)?)\\s*(?:g|ml)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(s.startIndex..., in: s)
                let matches = regex.matches(in: s, range: range)
                if let last = matches.last, let r = Range(last.range(at: 1), in: s) {
                    let num = s[r].replacingOccurrences(of: ",", with: ".")
                    if let g = Double(num), g > 0, g < 2000 { return g }
                }
            }
        }
        return nil
    }
}

/// OFF liefert Zahlen mal als Number, mal als String → tolerant dekodieren.
struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let saturatedFat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?   // Gramm pro 100 g
    let salt100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g   = "energy-kcal_100g"
        case energyKJ100g     = "energy_100g"      // viele EU-Produkte liefern NUR kJ
        case proteins100g     = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g          = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case fiber100g        = "fiber_100g"
        case sugars100g       = "sugars_100g"
        case sodium100g       = "sodium_100g"
        case salt100g         = "salt_100g"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func num(_ key: CodingKeys) -> Double? {
            if let d = try? c.decode(Double.self, forKey: key) { return d }
            if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
            return nil
        }
        // kcal direkt – sonst aus kJ ableiten (1 kcal = 4,184 kJ), damit EU-Produkte ohne
        // kcal-Feld nicht mit 0 Kalorien erscheinen.
        energyKcal100g    = num(.energyKcal100g) ?? num(.energyKJ100g).map { ($0 / 4.184).rounded() }
        proteins100g      = num(.proteins100g)
        carbohydrates100g = num(.carbohydrates100g)
        fat100g           = num(.fat100g)
        saturatedFat100g  = num(.saturatedFat100g)
        fiber100g         = num(.fiber100g)
        sugars100g        = num(.sugars100g)
        sodium100g        = num(.sodium100g)
        salt100g          = num(.salt100g)
    }

    /// Natrium in mg/100 g; fällt auf Salz/2.5 zurück.
    var sodiumMgPer100g: Double? {
        if let s = sodium100g { return s * 1000 }
        if let salt = salt100g { return (salt / 2.5) * 1000 }
        return nil
    }
}
