import Foundation
import SwiftData

/// Stammdaten eines Lebensmittels (aus Open Food Facts gecacht oder manuell angelegt).
/// Nährwerte werden pro 100 g gespeichert.
@Model
final class FoodItem {
    @Attribute(.unique) var id: UUID
    var barcode: String?
    var name: String
    var brand: String?

    var kcalPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var sodiumMgPer100g: Double?

    var lastFetched: Date?

    // Erfassungs-Komfort (additiv, SwiftData-Leichtmigration):
    var isFavorite: Bool = false        // A5: Favoriten
    var useCount: Int = 0               // A7: „Häufig"-Ranking
    var lastGrams: Double = 100         // A2: 1-Tipp-Wiederholung mit letzter Portion

    // KI-Portionsschätzung (Gericht-Foto): ganze erkannte Portion + Bezeichnung.
    var aiPortionGrams: Double?         // z. B. 215 (ein Big Mac)
    var aiPortionLabel: String?         // z. B. „1 Hamburger"

    // Herstellerdeklarierte Portion in Gramm (Open Food Facts), z. B. 1 Riegel = 20,7 g.
    var servingSizeG: Double?

    // Mikronährstoffe je 100 g (Vitamine/Mineralstoffe), Schlüssel laut NutrientCatalog.
    // SwiftData-sicher als JSON-Data persistiert; die [String: Double]-API bleibt unverändert,
    // damit ein direkt gespeichertes Dictionary nicht den ModelContainer-Aufbau sprengt.
    private var microsData: Data?
    var micros: [String: Double] {
        get {
            guard let microsData, !microsData.isEmpty,
                  let dict = try? JSONDecoder().decode([String: Double].self, from: microsData)
            else { return [:] }
            return dict
        }
        set { microsData = (try? JSONEncoder().encode(newValue)) }
    }

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.food)
    var entries: [FoodEntry] = []

    init(id: UUID = UUID(), name: String, barcode: String? = nil, brand: String? = nil) {
        self.id = id
        self.name = name
        self.barcode = barcode
        self.brand = brand
    }

    /// Benannte Portionen / Hausmaße (A1) – aus dem Namen abgeleitet, plus immer Gramm.
    /// Keine Persistenz nötig: heuristisch über Kategorie-Schlüsselwörter.
    var servings: [Serving] { Serving.presets(for: name) }
}

/// Eine benannte Portion: Anzeigename + Gramm-Äquivalent (A1).
struct Serving: Identifiable, Hashable, Sendable {
    var id: String { label }
    let label: String      // z. B. „1 mittel (180 g)"
    let grams: Double

    /// Sinnvolle Default-Portionen je nach Lebensmittel-Kategorie (Heuristik über den Namen).
    static func presets(for name: String) -> [Serving] {
        let n = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        func has(_ words: [String]) -> Bool { words.contains { n.contains($0) } }
        var out: [Serving] = []

        if has(["apfel","apple","birne","pear","orange","banane","banana","pfirsich","nektarine","granatapfel","mango","kiwi","tomate","gurke","paprika","zwiebel","kartoffel","ei "," ei","egg"]) {
            out += [Serving(label: "1 klein", grams: 100), Serving(label: "1 mittel", grams: 150), Serving(label: "1 groß", grams: 200)]
        } else if has(["brot","bread","toast","knaecke","knäcke","zwieback"]) {
            out += [Serving(label: "1 Scheibe", grams: 40), Serving(label: "2 Scheiben", grams: 80)]
        } else if has(["broetchen","brötchen","semmel","bagel","croissant","muffin","donut"]) {
            out += [Serving(label: "1 Stück", grams: 60)]
        } else if has(["milch","milk","saft","juice","cola","limo","bier","beer","wein","wine","wasser","water","kaffee","tee","tea","smoothie","shake","drink","kakao"]) {
            out += [Serving(label: "1 Glas (200 ml)", grams: 200), Serving(label: "1 Tasse (250 ml)", grams: 250), Serving(label: "0,5 L", grams: 500)]
        } else if has(["joghurt","yogurt","quark","skyr","pudding","frischkaese","frischkäse"]) {
            out += [Serving(label: "1 Becher (150 g)", grams: 150), Serving(label: "1 Becher (250 g)", grams: 250)]
        } else if has(["reis","rice","nudel","pasta","spaghetti","couscous","quinoa","bulgur","kartoffel","linsen","bohnen","kichererbsen"]) {
            out += [Serving(label: "kleine Portion (150 g)", grams: 150), Serving(label: "Portion (250 g)", grams: 250)]
        } else if has(["haferflocken","oats","muesli","müsli","cornflakes","granola"]) {
            out += [Serving(label: "kleine Portion (40 g)", grams: 40), Serving(label: "Portion (60 g)", grams: 60)]
        } else if has(["kaese","käse","gouda","cheddar","emmentaler","parmesan","feta","mozzarella"]) {
            out += [Serving(label: "1 Scheibe (25 g)", grams: 25), Serving(label: "Portion (50 g)", grams: 50)]
        } else if has(["nuss","nuesse","nüsse","mandeln","walnuss","cashew","pistazien","erdnuss"]) {
            out += [Serving(label: "Handvoll (25 g)", grams: 25), Serving(label: "Portion (50 g)", grams: 50)]
        } else if has(["kitkat","kit kat","snickers","twix","mars ","bounty","milky way","balisto","duplo","hanuta","müsliriegel","muesliriegel","proteinriegel","riegel"]) {
            out += [Serving(label: "1 Riegel (ca. 21 g)", grams: 21), Serving(label: "1 großer Riegel (ca. 45 g)", grams: 45)]
        } else if has(["schokolade","chocolate","praline"]) {
            out += [Serving(label: "1 Stück (ca. 8 g)", grams: 8), Serving(label: "1 Reihe (ca. 25 g)", grams: 25), Serving(label: "Tafel (100 g)", grams: 100)]
        } else if has(["keks","cookie","biscuit","plätzchen","plaetzchen","waffel"]) {
            out += [Serving(label: "1 Stück (ca. 12 g)", grams: 12), Serving(label: "3 Stück (ca. 36 g)", grams: 36)]
        } else if has(["bonbon","gummibär","gummibaer","fruchtgummi","lakritz"]) {
            out += [Serving(label: "Handvoll (25 g)", grams: 25), Serving(label: "Tüte (200 g)", grams: 200)]
        } else if has(["pizza"]) {
            out += [Serving(label: "1 Stück (125 g)", grams: 125), Serving(label: "ganze (300 g)", grams: 300)]
        } else if has(["ei","egg"]) {
            out += [Serving(label: "1 Ei (60 g)", grams: 60)]
        } else {
            out += [Serving(label: "Portion (100 g)", grams: 100)]
        }
        out.append(Serving(label: "100 g/ml", grams: 100))
        return out
    }
}
