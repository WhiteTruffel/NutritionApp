import Foundation

/// Gruppierung der Mikronährstoffe in der Auswertung.
enum NutrientGroup: String, CaseIterable {
    case vitamin = "Vitamine"
    case mineral = "Mineralstoffe"
    case other   = "Weitere"
}

/// Definition eines verfolgten Nährstoffs: Schlüssel, Anzeige, Einheit, Tagesreferenz (RDA
/// für Erwachsene, grob nach DACH/EU), Gruppe und USDA-FoodData-Central-Nährstoffnummer.
struct NutrientDef: Identifiable {
    let key: String
    let label: String
    var localizedLabel: String { "nutrient.\(key)".localized() }
    let unit: String        // "mg" | "µg" | "g"
    let rda: Double          // Tagesreferenzmenge Erwachsene
    let group: NutrientGroup
    let usdaNumber: String   // FDC nutrientNumber
    var id: String { key }
}

/// Kuratierter Cronometer-naher Satz an Vitaminen, Mineralstoffen und Fett-Details.
/// Werte je 100 g werden in `FoodItem.micros` unter `key` gespeichert.
enum NutrientCatalog {
    static let all: [NutrientDef] = [
        // Vitamine
        NutrientDef(key: "vitaminA",   label: "Vitamin A",            unit: "µg", rda: 800,  group: .vitamin, usdaNumber: "320"),
        NutrientDef(key: "vitaminC",   label: "Vitamin C",            unit: "mg", rda: 100,  group: .vitamin, usdaNumber: "401"),
        NutrientDef(key: "vitaminD",   label: "Vitamin D",            unit: "µg", rda: 20,   group: .vitamin, usdaNumber: "328"),
        NutrientDef(key: "vitaminE",   label: "Vitamin E",            unit: "mg", rda: 14,   group: .vitamin, usdaNumber: "323"),
        NutrientDef(key: "vitaminK",   label: "Vitamin K",            unit: "µg", rda: 70,   group: .vitamin, usdaNumber: "430"),
        NutrientDef(key: "thiamin",    label: "Vitamin B1 (Thiamin)", unit: "mg", rda: 1.1,  group: .vitamin, usdaNumber: "404"),
        NutrientDef(key: "riboflavin", label: "Vitamin B2 (Riboflavin)", unit: "mg", rda: 1.4, group: .vitamin, usdaNumber: "405"),
        NutrientDef(key: "niacin",     label: "Vitamin B3 (Niacin)",  unit: "mg", rda: 15,   group: .vitamin, usdaNumber: "406"),
        NutrientDef(key: "vitaminB6",  label: "Vitamin B6",           unit: "mg", rda: 1.4,  group: .vitamin, usdaNumber: "415"),
        NutrientDef(key: "folate",     label: "Folat (B9)",           unit: "µg", rda: 300,  group: .vitamin, usdaNumber: "417"),
        NutrientDef(key: "vitaminB12", label: "Vitamin B12",          unit: "µg", rda: 4,    group: .vitamin, usdaNumber: "418"),
        NutrientDef(key: "pantothenic", label: "Vitamin B5 (Pantothensäure)", unit: "mg", rda: 6, group: .vitamin, usdaNumber: "410"),
        NutrientDef(key: "biotin",     label: "Vitamin B7 (Biotin)",  unit: "µg", rda: 40,   group: .vitamin, usdaNumber: "416"),
        NutrientDef(key: "choline",    label: "Cholin",               unit: "mg", rda: 400,  group: .vitamin, usdaNumber: "421"),
        // Mineralstoffe
        NutrientDef(key: "calcium",    label: "Kalzium",   unit: "mg", rda: 1000, group: .mineral, usdaNumber: "301"),
        NutrientDef(key: "iron",       label: "Eisen",     unit: "mg", rda: 14,   group: .mineral, usdaNumber: "303"),
        NutrientDef(key: "magnesium",  label: "Magnesium", unit: "mg", rda: 350,  group: .mineral, usdaNumber: "304"),
        NutrientDef(key: "phosphorus", label: "Phosphor",  unit: "mg", rda: 700,  group: .mineral, usdaNumber: "305"),
        NutrientDef(key: "potassium",  label: "Kalium",    unit: "mg", rda: 4000, group: .mineral, usdaNumber: "306"),
        NutrientDef(key: "zinc",       label: "Zink",      unit: "mg", rda: 10,   group: .mineral, usdaNumber: "309"),
        NutrientDef(key: "copper",     label: "Kupfer",    unit: "mg", rda: 1.3,  group: .mineral, usdaNumber: "312"),
        NutrientDef(key: "manganese",  label: "Mangan",    unit: "mg", rda: 2,    group: .mineral, usdaNumber: "315"),
        NutrientDef(key: "selenium",   label: "Selen",     unit: "µg", rda: 60,   group: .mineral, usdaNumber: "317"),
        // Weitere (Fett-Detail)
        NutrientDef(key: "saturatedFat", label: "Gesättigte Fettsäuren", unit: "g",  rda: 20,  group: .other, usdaNumber: "606"),
        NutrientDef(key: "monoFat",      label: "Einfach ungesättigt",   unit: "g",  rda: 25,  group: .other, usdaNumber: "645"),
        NutrientDef(key: "polyFat",      label: "Mehrfach ungesättigt",  unit: "g",  rda: 15,  group: .other, usdaNumber: "646"),
        NutrientDef(key: "omega3",       label: "Omega-3 (ALA)",         unit: "g",  rda: 2,   group: .other, usdaNumber: "851"),
        NutrientDef(key: "transFat",     label: "Trans-Fettsäuren",      unit: "g",  rda: 2,   group: .other, usdaNumber: "605"),
        NutrientDef(key: "cholesterol",  label: "Cholesterin",           unit: "mg", rda: 300, group: .other, usdaNumber: "601"),
    ]

    /// Schneller Lookup USDA-Nummer → Definition.
    static let byUsdaNumber: [String: NutrientDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.usdaNumber, $0) })

    static func defs(in group: NutrientGroup) -> [NutrientDef] { all.filter { $0.group == group } }
}
