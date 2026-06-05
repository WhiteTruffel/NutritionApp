import Foundation

/// Koffein-Pharmakokinetik (HiCoffee-Prinzip): exponentieller Abbau je Dosis nach
/// Halbwertszeit. Standard-Halbwertszeit beim Erwachsenen ≈ 5 h (Bereich 3–7 h).
///
/// Wirksames Koffein im Körper = Σ Dosis · 0,5^(Δt / Halbwertszeit).
enum CaffeineKinetics {
    /// Standard-Halbwertszeit in Stunden.
    static let defaultHalfLifeHours: Double = 5.0

    /// Aktuell wirksames Koffein (mg) zum Zeitpunkt `now`. Zukünftige Dosen werden ignoriert.
    static func active(at now: Date,
                       doses: [(date: Date, mg: Double)],
                       halfLifeHours: Double = defaultHalfLifeHours) -> Double {
        guard halfLifeHours > 0 else { return 0 }
        return doses.reduce(0) { sum, d in
            let hours = now.timeIntervalSince(d.date) / 3600
            guard hours >= 0 else { return sum }
            return sum + d.mg * pow(0.5, hours / halfLifeHours)
        }
    }

    /// Erster Zeitpunkt ab `start`, zu dem das wirksame Koffein unter `threshold` mg fällt.
    /// Gibt nil zurück, wenn das innerhalb von 48 h nicht passiert (sollte praktisch nie sein).
    static func timeBelow(_ threshold: Double,
                          doses: [(date: Date, mg: Double)],
                          from start: Date,
                          halfLifeHours: Double = defaultHalfLifeHours) -> Date? {
        guard !doses.isEmpty else { return nil }
        if active(at: start, doses: doses, halfLifeHours: halfLifeHours) < threshold { return start }
        var t = start
        let end = start.addingTimeInterval(48 * 3600)
        let step: TimeInterval = 5 * 60
        while t <= end {
            if active(at: t, doses: doses, halfLifeHours: halfLifeHours) < threshold { return t }
            t = t.addingTimeInterval(step)
        }
        return nil
    }

    /// Kurvenpunkte für die Abbau-Visualisierung von `start` bis `end`.
    static func curve(doses: [(date: Date, mg: Double)],
                      from start: Date, to end: Date,
                      halfLifeHours: Double = defaultHalfLifeHours,
                      stepMinutes: Double = 15) -> [CaffeinePoint] {
        guard end > start else { return [] }
        var pts: [CaffeinePoint] = []
        var t = start
        let step = stepMinutes * 60
        while t <= end {
            pts.append(CaffeinePoint(date: t, mg: active(at: t, doses: doses, halfLifeHours: halfLifeHours)))
            t = t.addingTimeInterval(step)
        }
        return pts
    }
}

/// Ein Punkt der Koffein-Abbaukurve (für Swift Charts).
struct CaffeinePoint: Identifiable {
    let id = UUID()
    let date: Date
    let mg: Double
}

/// Gewichtsabhängige Richtwerte (EFSA-orientiert).
struct CaffeineGuide {
    let weightKg: Double

    /// Unbedenkliche Tagesmenge: ≈ 5,7 mg/kg, gedeckelt bei 400 mg (EFSA Erwachsene).
    var dailyLimitMg: Double { min(400, (5.7 * weightKg).rounded()) }

    /// Unbedenkliche Einzeldosis: ≈ 3 mg/kg (EFSA).
    var singleLimitMg: Double { (3 * weightKg).rounded() }

    /// Schlaf-Schwelle: unter diesem Restwert ist Einschlafen kaum noch beeinträchtigt.
    var sleepThresholdMg: Double { max(50, (0.7 * weightKg).rounded()) }
}

/// Getränke-Vorlagen mit typischem Koffeingehalt (mg) und Flüssigkeitsanteil (ml).
struct DrinkPreset: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let caffeineMg: Double
    let waterMl: Double

    static let caffeinated: [DrinkPreset] = [
        DrinkPreset(name: "Espresso", symbol: "cup.and.saucer.fill", caffeineMg: 63, waterMl: 30),
        DrinkPreset(name: "Doppio", symbol: "cup.and.saucer.fill", caffeineMg: 126, waterMl: 60),
        DrinkPreset(name: "Lungo", symbol: "cup.and.saucer.fill", caffeineMg: 80, waterMl: 90),
        DrinkPreset(name: "Filterkaffee", symbol: "cup.and.saucer.fill", caffeineMg: 95, waterMl: 200),
        DrinkPreset(name: "Cappuccino", symbol: "cup.and.saucer.fill", caffeineMg: 63, waterMl: 150),
        DrinkPreset(name: "Latte", symbol: "cup.and.saucer.fill", caffeineMg: 63, waterMl: 250),
        DrinkPreset(name: "Flat White", symbol: "cup.and.saucer.fill", caffeineMg: 130, waterMl: 160),
        DrinkPreset(name: "Americano", symbol: "cup.and.saucer.fill", caffeineMg: 95, waterMl: 200),
        DrinkPreset(name: "Cold Brew", symbol: "cup.and.saucer.fill", caffeineMg: 200, waterMl: 300),
        DrinkPreset(name: "Schwarztee", symbol: "mug.fill", caffeineMg: 47, waterMl: 250),
        DrinkPreset(name: "Grüntee", symbol: "mug.fill", caffeineMg: 28, waterMl: 250),
        DrinkPreset(name: "Mate", symbol: "leaf.fill", caffeineMg: 65, waterMl: 330),
        DrinkPreset(name: "Cola", symbol: "takeoutbag.and.cup.and.straw.fill", caffeineMg: 32, waterMl: 330),
        DrinkPreset(name: "Energydrink", symbol: "bolt.fill", caffeineMg: 80, waterMl: 250),
        DrinkPreset(name: "Eistee", symbol: "takeoutbag.and.cup.and.straw.fill", caffeineMg: 25, waterMl: 330),
    ]
}
