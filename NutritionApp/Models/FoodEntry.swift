import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var label: String {
        switch self {
        case .breakfast: "Frühstück"
        case .lunch:     "Mittag"
        case .dinner:    "Abend"
        case .snack:     "Snack"
        }
    }
}

/// Eine konkret geloggte Portion. `id` dient zugleich als HKMetadataKeyExternalUUID
/// beim HealthKit-Sync, damit Re-Syncs keine Duplikate erzeugen.
@Model
final class FoodEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var grams: Double
    var mealTypeRaw: String
    var food: FoodItem?
    var syncedToHealthKit: Bool
    var importedFromHealth: Bool = false   // aus Apple Health importiert (nicht zurückschreiben)
    var healthKitUUID: UUID?               // UUID der HK-Korrelation → Dedup bei Re-Import

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date = .now, grams: Double,
         mealType: MealType, food: FoodItem?,
         importedFromHealth: Bool = false, healthKitUUID: UUID? = nil) {
        self.id = id
        self.date = date
        self.grams = grams
        self.mealTypeRaw = mealType.rawValue
        self.food = food
        self.syncedToHealthKit = false
        self.importedFromHealth = importedFromHealth
        self.healthKitUUID = healthKitUUID
    }

    private func scaled(_ per100g: Double?) -> Double? { per100g.map { $0 * grams / 100 } }
    var kcal: Double?     { scaled(food?.kcalPer100g) }
    var proteinG: Double? { scaled(food?.proteinPer100g) }
    var carbsG: Double?   { scaled(food?.carbsPer100g) }
    var fatG: Double?     { scaled(food?.fatPer100g) }
    var satFatG: Double?  { scaled(food?.saturatedFatPer100g) }
    var fiberG: Double?   { scaled(food?.fiberPer100g) }
    var sugarG: Double?   { scaled(food?.sugarPer100g) }
    var sodiumMg: Double? { scaled(food?.sodiumMgPer100g) }

    /// Sendable-Snapshot zum Übergeben an den HealthKit-Aktor.
    func makePayload() -> MealPayload {
        MealPayload(id: id, name: food?.name ?? "Mahlzeit", date: date,
                    kcal: kcal, proteinG: proteinG, carbsG: carbsG, fatG: fatG,
                    fiberG: fiberG, sugarG: sugarG, sodiumMg: sodiumMg)
    }
}
