import Foundation
import SwiftData

/// Ein Gewichts-Messpunkt für den Fortschrittsverlauf.
@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKg: Double
    var healthKitUUID: UUID?       // gesetzt, wenn aus Apple Health importiert → Dedup

    init(id: UUID = UUID(), date: Date = .now, weightKg: Double, healthKitUUID: UUID? = nil) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.healthKitUUID = healthKitUUID
    }
}
