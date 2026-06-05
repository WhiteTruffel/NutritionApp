import Foundation

/// Sendable-Wertobjekt: überquert die Aktorgrenze zum HealthKit-Aktor.
/// Niemals @Model-Instanzen über Aktorgrenzen reichen – nur diesen Snapshot.
struct MealPayload: Sendable, Identifiable {
    let id: UUID            // == FoodEntry.id → HKMetadataKeyExternalUUID
    let name: String
    let date: Date
    var kcal: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var sugarG: Double?
    var sodiumMg: Double?
}
