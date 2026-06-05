import Foundation
import SwiftData

enum IntakeKind: String, Codable {
    case water      // Menge in ml
    case caffeine   // Menge in mg
}

/// Eine Wasser- oder Koffein-Aufnahme (Schnell-Logging am Dashboard).
@Model
final class IntakeEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var kindRaw: String
    var amount: Double

    var kind: IntakeKind {
        get { IntakeKind(rawValue: kindRaw) ?? .water }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date = .now, kind: IntakeKind, amount: Double) {
        self.id = id
        self.date = date
        self.kindRaw = kind.rawValue
        self.amount = amount
    }
}
