import Foundation
import HealthKit

/// Kompakte, Sendable-Darstellung eines Apple-Health-Workouts für den Training-Reiter.
struct WorkoutSummary: Identifiable, Sendable {
    let id: UUID
    let name: String            // deutscher Name (z. B. „Laufen")
    let symbol: String          // SF-Symbol
    let start: Date
    let durationMin: Double
    let kcal: Double?
    let distanceMeters: Double?
}

extension HKWorkoutActivityType {
    /// Deutscher Anzeigename der gängigsten Workout-Typen.
    var germanName: String {
        switch self {
        case .running:                    return "Laufen"
        case .walking:                    return "Gehen"
        case .hiking:                     return "Wandern"
        case .cycling:                    return "Radfahren"
        case .swimming:                   return "Schwimmen"
        case .traditionalStrengthTraining,
             .functionalStrengthTraining: return "Krafttraining"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga:                       return "Yoga"
        case .pilates:                    return "Pilates"
        case .elliptical:                 return "Crosstrainer"
        case .rowing:                     return "Rudern"
        case .stairClimbing,
             .stairs:                     return "Treppensteigen"
        case .coreTraining:               return "Core-Training"
        case .dance, .cardioDance:        return "Tanzen"
        case .soccer:                     return "Fußball"
        case .tennis:                     return "Tennis"
        case .basketball:                 return "Basketball"
        case .golf:                       return "Golf"
        case .boxing, .kickboxing:        return "Boxen"
        case .climbing:                   return "Klettern"
        case .skatingSports:              return "Skaten"
        case .crossTraining:              return "Cross-Training"
        case .mixedCardio:                return "Cardio"
        case .flexibility:                return "Beweglichkeit"
        case .cooldown:                   return "Cooldown"
        default:                          return "Training"
        }
    }

    /// Passendes SF-Symbol.
    var symbolName: String {
        switch self {
        case .running:                    return "figure.run"
        case .walking, .hiking:           return "figure.walk"
        case .cycling:                    return "figure.outdoor.cycle"
        case .swimming:                   return "figure.pool.swim"
        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .coreTraining:               return "dumbbell.fill"
        case .highIntensityIntervalTraining,
             .crossTraining, .mixedCardio: return "bolt.heart.fill"
        case .yoga, .pilates, .flexibility: return "figure.yoga"
        case .elliptical:                 return "figure.elliptical"
        case .rowing:                     return "figure.rower"
        case .dance, .cardioDance:        return "figure.dance"
        case .boxing, .kickboxing:        return "figure.boxing"
        default:                          return "figure.mixed.cardio"
        }
    }
}
