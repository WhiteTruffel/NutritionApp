import Foundation
import SwiftData

/// Schreibt importierte Health-Mahlzeiten in einen eigenen SwiftData-Kontext (Swift-6-sicher).
@ModelActor
actor SyncImporter {
    /// Legt fehlende Einträge an; überspringt eigene und bereits importierte. Gibt die Anzahl neuer Einträge zurück.
    func importMeals(_ meals: [ImportedMeal]) throws -> Int {
        var count = 0
        for meal in meals where !meal.isOwn {
            let target: UUID? = meal.hkUUID
            let descriptor = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.healthKitUUID == target })
            if (try modelContext.fetch(descriptor).first) != nil { continue }

            // Importierte Mahlzeiten tragen absolute Werte → als „Food" mit Werten pro 100 g, 100 g gegessen.
            let food = FoodItem(name: meal.name)
            food.kcalPer100g     = meal.kcal
            food.proteinPer100g  = meal.proteinG
            food.carbsPer100g    = meal.carbsG
            food.fatPer100g      = meal.fatG
            food.fiberPer100g    = meal.fiberG
            food.sugarPer100g    = meal.sugarG
            food.sodiumMgPer100g = meal.sodiumMg
            food.lastFetched = .now
            modelContext.insert(food)

            let entry = FoodEntry(date: meal.date, grams: 100,
                                  mealType: Self.mealType(for: meal.date), food: food,
                                  importedFromHealth: true, healthKitUUID: meal.hkUUID)
            entry.syncedToHealthKit = true   // nie zurückschreiben
            modelContext.insert(entry)
            count += 1
        }
        if count > 0 { try modelContext.save() }
        return count
    }

    /// Importiert Gewichts-Messpunkte aus Apple Health. Dedup über HK-UUID und – für
    /// App-eigene Werte, die via App nach Health geschrieben wurden – über Tag + ~Gewicht.
    func importWeights(_ samples: [WeightSample]) throws -> Int {
        guard !samples.isEmpty else { return 0 }
        let existing = try modelContext.fetch(FetchDescriptor<WeightEntry>())
        let existingUUIDs = Set(existing.compactMap { $0.healthKitUUID })
        let cal = Calendar.current
        var seen: [(day: Date, kg: Double)] = existing.map { (cal.startOfDay(for: $0.date), $0.weightKg) }
        var count = 0
        for s in samples {
            if existingUUIDs.contains(s.uuid) { continue }
            let day = cal.startOfDay(for: s.date)
            if seen.contains(where: { cal.isDate($0.day, inSameDayAs: day) && abs($0.kg - s.kg) < 0.1 }) { continue }
            modelContext.insert(WeightEntry(date: s.date, weightKg: s.kg, healthKitUUID: s.uuid))
            seen.append((day, s.kg))
            count += 1
        }
        if count > 0 { try modelContext.save() }
        return count
    }

    private static func mealType(for date: Date) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11:  return .breakfast
        case 11..<16: return .lunch
        case 16..<22: return .dinner
        default:      return .snack
        }
    }
}

/// Bündelt Lesen (HealthKit) + Schreiben (SwiftData). Sendable, daher auch aus Background-Callbacks nutzbar.
struct HealthSyncCoordinator: Sendable {
    let health: NutritionHealthStore
    let container: ModelContainer

    private static let anchorKey = "healthFoodAnchor"

    /// Inkrementeller Import: liest Deltas seit dem letzten Anchor und schreibt sie weg.
    @discardableResult
    func sync() async -> Int {
        let anchor = UserDefaults.standard.data(forKey: Self.anchorKey)
        let result = await health.importNewMeals(anchor: anchor)
        let importer = SyncImporter(modelContainer: container)
        let count = (try? await importer.importMeals(result.meals)) ?? 0
        if let newAnchor = result.anchor {
            UserDefaults.standard.set(newAnchor, forKey: Self.anchorKey)
        }
        await syncWeights()   // Gewichtsverlauf aus Apple Health mitziehen
        return count
    }

    /// Importiert den Gewichtsverlauf aus Apple Health (Historie + neue Messpunkte).
    @discardableResult
    func syncWeights() async -> Int {
        let samples = await health.readWeightHistory()
        let importer = SyncImporter(modelContainer: container)
        return (try? await importer.importWeights(samples)) ?? 0
    }

    /// Registriert Observer + Background Delivery, die bei Änderungen `sync()` auslösen.
    func startBackgroundSync() async {
        await health.startBackgroundDelivery {
            await sync()
        }
    }
}
