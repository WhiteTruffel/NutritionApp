import Foundation
import SwiftData

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var label: String { self == .male ? "settings.gender.male".localized() : "settings.gender.female".localized() }
}

/// Grundaktivität OHNE Training (NEAT) – Sport wird separat aus Apple Health ergänzt,
/// damit es keine Doppelzählung gibt.
enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, high, veryHigh
    var id: String { rawValue }
    var factor: Double {
        switch self {
        case .sedentary: 1.2     // überwiegend sitzend
        case .light:     1.35    // etwas Alltagsbewegung
        case .moderate:  1.5     // viel auf den Beinen
        case .high:      1.65    // stehender/körperlicher Beruf
        case .veryHigh:  1.8     // schwere körperliche Arbeit
        }
    }
    var label: String {
        switch self {
        case .sedentary: "activity.sedentary".localized()
        case .light:     "activity.light".localized()
        case .moderate:  "activity.moderate".localized()
        case .high:      "activity.high".localized()
        case .veryHigh:  "activity.veryhigh".localized()
        }
    }
}

/// Verschiedene Makro-Ansätze – der Nutzer wählt im Ziele-Screen.
enum MacroStrategy: String, Codable, CaseIterable, Identifiable {
    case balanced, lowCarb, highProtein, keto, proteinPerKg, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .balanced:     "macro.balanced".localized()
        case .lowCarb:      "macro.lowcarb".localized()
        case .highProtein:  "macro.highprotein".localized()
        case .keto:         "macro.keto".localized()
        case .proteinPerKg: "macro.proteinperkg".localized()
        case .custom:       "macro.custom".localized()
        }
    }
}

@Model
final class UserProfile {
    var sexRaw: String
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activityRaw: String
    var weeklyRateKg: Double        // negativ = abnehmen, 0 = halten, positiv = zunehmen
    var macroStrategyRaw: String
    var useExerciseCalories: Bool
    var customCarbPct: Double
    var customProteinPct: Double
    var customFatPct: Double
    var bodyFatPercent: Double?     // optional, aus Apple Health → genauerer Grundumsatz
    var useAdaptiveTDEE: Bool = false   // Goldstandard: Umsatz aus Gewichtstrend + Zufuhr lernen
    var skinTypeRaw: String = FitzpatrickSkinType.typeII.rawValue   // Fitzpatrick skin type, app-owned (HealthKit's is read-only)

    init(sex: Sex = .male, age: Int = 30, heightCm: Double = 175, weightKg: Double = 75,
         activity: ActivityLevel = .moderate, weeklyRateKg: Double = 0,
         macroStrategy: MacroStrategy = .balanced, useExerciseCalories: Bool = true,
         customCarbPct: Double = 50, customProteinPct: Double = 20, customFatPct: Double = 30,
         bodyFatPercent: Double? = nil) {
        self.bodyFatPercent = bodyFatPercent
        self.sexRaw = sex.rawValue
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityRaw = activity.rawValue
        self.weeklyRateKg = weeklyRateKg
        self.macroStrategyRaw = macroStrategy.rawValue
        self.useExerciseCalories = useExerciseCalories
        self.customCarbPct = customCarbPct
        self.customProteinPct = customProteinPct
        self.customFatPct = customFatPct
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }
    var macroStrategy: MacroStrategy {
        get { MacroStrategy(rawValue: macroStrategyRaw) ?? .balanced }
        set { macroStrategyRaw = newValue.rawValue }
    }

    var skinType: FitzpatrickSkinType {
        get { FitzpatrickSkinType(rawValue: skinTypeRaw) ?? .typeII }
        set { skinTypeRaw = newValue.rawValue }
    }

    // MARK: Best-Practice-Rechnung

    /// Grundumsatz: Katch-McArdle bei bekanntem Körperfett (genauer, nutzt Magermasse),
    /// sonst Mifflin-St Jeor.
    var bmr: Double {
        if let bf = bodyFatPercent, bf > 0, bf < 100 {
            let leanMass = weightKg * (1 - bf / 100)
            return 370 + 21.6 * leanMass
        }
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return base + (sex == .male ? 5 : -161)
    }

    var bmrMethod: String {
        if let bf = bodyFatPercent, bf > 0, bf < 100 { return "Katch-McArdle" }
        return "Mifflin-St Jeor"
    }

    /// Gesamtumsatz = BMR × Aktivitätsfaktor.
    var tdee: Double { bmr * activity.factor }

    /// Sicherheits-Untergrenze (verhindert ungesund niedrige Ziele).
    var kcalFloor: Double { sex == .female ? 1200 : 1500 }

    /// Rohziel vor Kappung (für Hinweis, ob die Untergrenze greift).
    private var rawTarget: Double { tdee + weeklyRateKg * 7700 / 7 }
    var isFloored: Bool { rawTarget < kcalFloor }

    var kcalTarget: Double { max(kcalFloor, rawTarget).rounded() }

    var targets: NutritionTargets { macroTargets(forKcal: kcalTarget) }

    /// Makro-Ziele für ein beliebiges kcal-Ziel (z. B. den adaptiven Umsatz).
    func macroTargets(forKcal kcal: Double) -> NutritionTargets {
        let g = macroGrams(kcal: kcal)
        return NutritionTargets(kcal: kcal.rounded(),
                                carbsG: g.carbs.rounded(),
                                proteinG: g.protein.rounded(),
                                fatG: g.fat.rounded())
    }

    /// Tagesziel aus einem (adaptiv geschätzten) Umsatz + gewünschte Wochenrate, gekappt.
    func adaptiveKcalTarget(tdee: Double) -> Double {
        max(kcalFloor, (tdee + weeklyRateKg * 7700 / 7)).rounded()
    }

    private func macroGrams(kcal: Double) -> (carbs: Double, protein: Double, fat: Double) {
        func split(_ c: Double, _ p: Double, _ f: Double) -> (carbs: Double, protein: Double, fat: Double) {
            (kcal * c / 100 / 4, kcal * p / 100 / 4, kcal * f / 100 / 9)
        }
        switch macroStrategy {
        case .balanced:    return split(50, 20, 30)
        case .lowCarb:     return split(25, 35, 40)
        case .highProtein: return split(40, 35, 25)
        case .keto:        return split(5, 25, 70)
        case .custom:      return split(customCarbPct, customProteinPct, customFatPct)
        case .proteinPerKg:
            let proteinG = 1.8 * weightKg
            let remaining = max(0, kcal - proteinG * 4)
            return (remaining * 0.55 / 4, proteinG, remaining * 0.45 / 9)
        }
    }
}
