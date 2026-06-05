import Foundation

/// Tagesziele für Kalorien und Makros. Vorerst Code-Default (kein SwiftData-Schema-Eingriff);
/// im späteren „Ziele"-Schritt wird das editierbar gemacht.
struct NutritionTargets: Sendable, Equatable {
    var kcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double

    /// Sinnvoller Startwert: ~2000 kcal, ausgewogene Makroverteilung.
    static let `default` = NutritionTargets(kcal: 2000, carbsG: 250, proteinG: 100, fatG: 67)
}

/// Aufsummierte Tageswerte aus geloggten Einträgen.
struct MacroTotals: Sendable, Equatable {
    var kcal: Double = 0
    var carbsG: Double = 0
    var proteinG: Double = 0
    var fatG: Double = 0
}

extension Sequence where Element == FoodEntry {
    /// Summiert die (auf die Portion umgerechneten) Nährwerte aller Einträge.
    func totals() -> MacroTotals {
        reduce(into: MacroTotals()) { acc, e in
            acc.kcal     += e.kcal ?? 0
            acc.carbsG   += e.carbsG ?? 0
            acc.proteinG += e.proteinG ?? 0
            acc.fatG     += e.fatG ?? 0
        }
    }
}
