import Foundation
import SwiftData

/// Eine gespeicherte Mahlzeit/Rezept ("Mein Frühstück") für 1-Tap-Logging (BL8).
/// Die Komponenten werden als SwiftData-sicherer JSON-Snapshot abgelegt – unabhängig
/// von den FoodItem-Objekten, damit das Loggen ohne Fremdschlüssel-Auflösung funktioniert
/// und keine Dublette-/Migrations-Probleme entstehen.
@Model
final class MealTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var useCount: Int = 0
    private var componentsData: Data?

    var components: [MealComponent] {
        get {
            guard let componentsData, !componentsData.isEmpty,
                  let list = try? JSONDecoder().decode([MealComponent].self, from: componentsData)
            else { return [] }
            return list
        }
        set { componentsData = try? JSONEncoder().encode(newValue) }
    }

    init(id: UUID = UUID(), name: String, components: [MealComponent], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.componentsData = try? JSONEncoder().encode(components)
    }

    /// Summe der Kalorien über alle Komponenten (für die Anzeige).
    var totalKcal: Double {
        components.reduce(0) { $0 + ($1.kcalPer100g ?? 0) * $1.grams / 100 }
    }
}

/// Snapshot einer Mahlzeit-Komponente: Name, Menge und Nährwerte je 100 g.
struct MealComponent: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var grams: Double
    var kcalPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var sodiumMgPer100g: Double?
}
