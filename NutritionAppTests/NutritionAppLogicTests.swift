import XCTest
import SwiftData
@testable import NutritionApp

/// Automatische Tests der reinen Kernlogik – laufen im Simulator, kein Gerät nötig.
final class NutritionAppLogicTests: XCTestCase {

    // MARK: Kalorienrechner

    @MainActor
    func testMifflinStJeorUndTDEE() {
        let p = UserProfile(sex: .male, age: 30, heightCm: 175, weightKg: 75,
                            activity: .moderate, weeklyRateKg: 0, macroStrategy: .balanced)
        // BMR = 10*75 + 6.25*175 - 5*30 + 5 = 1698.75
        XCTAssertEqual(p.bmr, 1698.75, accuracy: 0.01)
        // TDEE = BMR * 1.5 (NEAT „mäßig aktiv")
        XCTAssertEqual(p.tdee, 1698.75 * 1.5, accuracy: 0.01)
        // Halten → Ziel = gerundeter TDEE = 2548
        XCTAssertEqual(p.kcalTarget, 2548, accuracy: 0.5)
        XCTAssertEqual(p.bmrMethod, "Mifflin-St Jeor")
    }

    @MainActor
    func testFrauBMRUndSicherheitsUntergrenze() {
        let p = UserProfile(sex: .female, age: 30, heightCm: 165, weightKg: 60,
                            activity: .sedentary, weeklyRateKg: -1.0)
        // BMR = 600 + 1031.25 - 150 - 161 = 1320.25
        XCTAssertEqual(p.bmr, 1320.25, accuracy: 0.01)
        // TDEE 1584.3 − 1100 (1 kg/Woche) = 484 → unter Floor 1200 → gekappt
        XCTAssertEqual(p.kcalTarget, 1200, accuracy: 0.5)
        XCTAssertTrue(p.isFloored)
    }

    @MainActor
    func testKatchMcArdleBeiKoerperfett() {
        let p = UserProfile(sex: .male, age: 30, heightCm: 180, weightKg: 80, bodyFatPercent: 20)
        // LBM = 64 kg; BMR = 370 + 21.6*64 = 1752.4
        XCTAssertEqual(p.bmr, 1752.4, accuracy: 0.01)
        XCTAssertEqual(p.bmrMethod, "Katch-McArdle")
    }

    @MainActor
    func testMakroSplitBalanced() {
        let p = UserProfile(sex: .male, age: 30, heightCm: 175, weightKg: 75,
                            activity: .moderate, weeklyRateKg: 0, macroStrategy: .balanced)
        let t = p.targets
        XCTAssertEqual(t.carbsG,   (t.kcal * 0.5 / 4).rounded(), accuracy: 1)
        XCTAssertEqual(t.proteinG, (t.kcal * 0.2 / 4).rounded(), accuracy: 1)
        XCTAssertEqual(t.fatG,     (t.kcal * 0.3 / 9).rounded(), accuracy: 1)
    }

    // MARK: Etikett-Parser (deutsche Nährwerttabelle)

    func testEtikettParserDeutsch() {
        let lines = [
            "Nährwerte pro 100 g",
            "Brennwert 1560 kJ / 370 kcal",
            "Fett 7,0 g",
            "davon gesättigte Fettsäuren 1,2 g",
            "Kohlenhydrate 60 g",
            "davon Zucker 1,1 g",
            "Eiweiß 13 g",
            "Ballaststoffe 9 g",
            "Salz 0,1 g"
        ]
        let r = NutritionLabelParser.parse(lines)
        XCTAssertEqual(r.kcalPer100g, 370)
        XCTAssertEqual(r.fatPer100g, 7.0)
        XCTAssertEqual(r.carbsPer100g, 60)
        XCTAssertEqual(r.sugarPer100g, 1.1)
        XCTAssertEqual(r.proteinPer100g, 13)
        XCTAssertEqual(r.fiberPer100g, 9)
        XCTAssertEqual(r.saltPer100g, 0.1)
        XCTAssertTrue(r.hasAny)
    }

    // MARK: Open Food Facts – tolerantes Decoding + Salz→Natrium

    func testOFFNutrimentsDecoding() throws {
        let json = Data("""
        {"energy-kcal_100g": 539, "proteins_100g": "6.3", "carbohydrates_100g": 57.5,
         "fat_100g": 30.9, "salt_100g": 0.107}
        """.utf8)
        let n = try JSONDecoder().decode(OFFNutriments.self, from: json)
        XCTAssertEqual(n.energyKcal100g, 539)
        XCTAssertEqual(n.proteins100g, 6.3)            // kam als String
        XCTAssertEqual(n.carbohydrates100g, 57.5)
        XCTAssertEqual(n.fat100g, 30.9)
        // Natrium aus Salz: 0.107 / 2.5 * 1000 ≈ 42.8 mg
        XCTAssertEqual(n.sodiumMgPer100g ?? -1, 0.107 / 2.5 * 1000, accuracy: 0.1)
    }

    // MARK: Tagessummen + Portionsumrechnung

    @MainActor
    func testPortionUndTagessummen() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FoodItem.self, FoodEntry.self, configurations: config)
        let ctx = container.mainContext

        let food = FoodItem(name: "Testlebensmittel")
        food.kcalPer100g = 100; food.proteinPer100g = 10
        food.carbsPer100g = 20; food.fatPer100g = 5
        ctx.insert(food)

        let entry = FoodEntry(grams: 200, mealType: .lunch, food: food)
        ctx.insert(entry)

        // 200 g → doppelte Werte
        XCTAssertEqual(entry.kcal, 200)
        XCTAssertEqual(entry.proteinG, 20)

        let totals = [entry].totals()
        XCTAssertEqual(totals.kcal, 200)
        XCTAssertEqual(totals.proteinG, 20)
        XCTAssertEqual(totals.carbsG, 40)
        XCTAssertEqual(totals.fatG, 10)
    }

    // MARK: Basis-Lebensmittel-DB (lokal, zweisprachig) – behebt „Apfel findet nichts"

    func testBasisSucheApfelDeutschUndEnglisch() async throws {
        let db = LocalFoodDatabase()
        let de = try await db.search("apfel")
        XCTAssertTrue(de.contains { $0.name == "Apfel" }, "Deutsch: 'apfel' muss Apfel finden")
        let en = try await db.search("apple")
        XCTAssertTrue(en.contains { $0.name == "Apfel" }, "Englisch: 'apple' muss Apfel finden")
        // Treffer hat sofort Nährwerte (kein Nachladen nötig).
        XCTAssertNotNil(de.first { $0.name == "Apfel" }?.kcalPer100g)
    }

    func testBasisSucheEnglischUndUmlautUnabhaengig() async throws {
        let r = try await LocalFoodDatabase().search("chicken")
        XCTAssertTrue(r.contains { $0.name == "Hähnchenbrust" })
        let r2 = try await LocalFoodDatabase().search("hahnchen")   // ohne Umlaut
        XCTAssertTrue(r2.contains { $0.name == "Hähnchenbrust" })
    }

    // MARK: OFF kJ-only → kcal abgeleitet (Defekt D-01)

    func testOFFKilojouleAbleitung() throws {
        let json = Data(#"{"energy_100g": 1560, "proteins_100g": 6}"#.utf8)
        let n = try JSONDecoder().decode(OFFNutriments.self, from: json)
        XCTAssertEqual(n.energyKcal100g ?? -1, 373, accuracy: 1)   // 1560 / 4,184 ≈ 373
    }

    func testOFFKcalHatVorrangVorKJ() throws {
        let json = Data(#"{"energy-kcal_100g": 539, "energy_100g": 2255}"#.utf8)
        let n = try JSONDecoder().decode(OFFNutriments.self, from: json)
        XCTAssertEqual(n.energyKcal100g, 539)
    }

    // MARK: Etikett-Parser – kombinierte Zeile + nachgestelltes kcal (Defekt D-02 / D-07)

    func testEtikettParserKombinierteZeile() {
        let r = NutritionLabelParser.parse(["Kohlenhydrate 60 g davon Zucker 1,1 g"])
        XCTAssertEqual(r.carbsPer100g, 60)    // vorher fälschlich nil
        XCTAssertEqual(r.sugarPer100g, 1.1)   // vorher fälschlich 60
    }

    func testEtikettParserKcalNachgestellt() {
        let r = NutritionLabelParser.parse(["Energie: kcal 370"])
        XCTAssertEqual(r.kcalPer100g, 370)
    }

    func testEtikettParserEnglisch() {
        let r = NutritionLabelParser.parse([
            "Carbohydrate 60g of which sugars 1.1g", "Fat 7g", "Saturated fat 1.2g", "Protein 13g"
        ])
        XCTAssertEqual(r.carbsPer100g, 60)
        XCTAssertEqual(r.sugarPer100g, 1.1)
        XCTAssertEqual(r.fatPer100g, 7)        // nicht die 1.2 aus der „saturated"-Zeile
        XCTAssertEqual(r.proteinPer100g, 13)
    }
}
