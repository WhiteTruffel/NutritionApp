import Foundation

/// Ergebnis der adaptiven Umsatz-Schätzung (MacroFactor-Prinzip).
struct AdaptiveEnergyResult: Sendable {
    let tdee: Double                 // geschätzter Gesamtumsatz (kcal/Tag)
    let loggedDays: Int              // Tage mit erfasster Nahrung im Fenster
    let windowDays: Int
    let weightSlopeKgPerWeek: Double // Gewichtstrend (kg/Woche), negativ = abnehmen
    let avgIntake: Double            // Ø Zufuhr (kcal/Tag) im Fenster
}

/// Adaptiver Energieumsatz aus echten Daten – statt Sport-Kalorien zu addieren.
///
/// Energiebilanz: TDEE ≈ Ø-Zufuhr − (Gewichtsänderung × 7700 kcal/kg) / Zeitraum.
/// Der Gewichtstrend wird per linearer Regression geglättet (robuster gegen Tagesschwankungen,
/// Wasser etc.). So „lernt" die App den wahren Umsatz inkl. Training aus dem Gewichtsverlauf,
/// ohne der (oft ungenauen) Kalorienzahl der Uhr zu vertrauen.
enum AdaptiveEnergy {
    static let kcalPerKg = 7700.0

    /// Mindestanforderungen, damit eine Schätzung als belastbar gilt.
    static let minLoggedDays = 7
    static let minWeightReadings = 2
    static let minSpanDays = 7.0

    /// - weights: (Datum, kg) – Gewichts-Messpunkte
    /// - dailyKcal: (Tagesbeginn, kcal-Summe) je Tag mit Erfassung
    static func estimate(weights: [(date: Date, kg: Double)],
                         dailyKcal: [(day: Date, kcal: Double)],
                         window: Int = 14,
                         asOf: Date = .now) -> AdaptiveEnergyResult? {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -window, to: cal.startOfDay(for: asOf)) else { return nil }

        let intake = dailyKcal.filter { $0.day >= start && $0.kcal > 0 }
        let pts = weights.filter { $0.date >= start }.sorted { $0.date < $1.date }
        guard intake.count >= minLoggedDays, pts.count >= minWeightReadings else { return nil }

        let avgIntake = intake.map(\.kcal).reduce(0, +) / Double(intake.count)

        // Lineare Regression Gewicht über Tage seit erstem Messpunkt → Steigung kg/Tag.
        let t0 = pts.first!.date
        let xs = pts.map { $0.date.timeIntervalSince(t0) / 86_400.0 }
        let ys = pts.map(\.kg)
        let span = xs.last! - xs.first!
        guard span >= minSpanDays else { return nil }

        let n = Double(xs.count)
        let sumX = xs.reduce(0, +), sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map(*).reduce(0, +)
        let sumXX = xs.map { $0 * $0 }.reduce(0, +)
        let denom = n * sumXX - sumX * sumX
        guard denom != 0 else { return nil }
        let slopePerDay = (n * sumXY - sumX * sumY) / denom   // kg/Tag

        // TDEE: Zufuhr minus die im Gewichtstrend gespeicherte/abgegebene Energie.
        let tdee = avgIntake - slopePerDay * kcalPerKg
        guard tdee > 800, tdee < 6000 else { return nil }     // Plausibilitäts-Klammer

        return AdaptiveEnergyResult(
            tdee: tdee.rounded(),
            loggedDays: intake.count,
            windowDays: window,
            weightSlopeKgPerWeek: slopePerDay * 7,
            avgIntake: avgIntake.rounded()
        )
    }
}
