import Foundation
import SwiftData

/// Seeds test data for hydration history and other features
final class TestDataSeeding {
    static func seedHydrationHistory(in modelContext: ModelContext) {
        // Check if data already exists
        var fetchDescriptor = FetchDescriptor<IntakeEntry>()
        fetchDescriptor.fetchLimit = 1
        if let _ = try? modelContext.fetch(fetchDescriptor).first {
            return // Data already exists
        }

        // Seed 12 weeks of hydration data
        let calendar = Calendar.current
        let now = Date()

        for weekOffset in -11...0 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now.startOfDay) else { continue }

            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }

                // Random daily intake between 1500-2700 ml
                let randomIntake = Double.random(in: 1500...2700)
                let numEntries = Int.random(in: 2...5)

                for _ in 0..<numEntries {
                    let entryAmount = randomIntake / Double(numEntries)
                    let entry = IntakeEntry(
                        date: date.addingTimeInterval(TimeInterval.random(in: 0...86400)),
                        kind: .water,
                        amount: entryAmount
                    )
                    modelContext.insert(entry)
                }
            }
        }

        try? modelContext.save()
    }

    static func seedWithContrastingData(in modelContext: ModelContext) {
        // Alternative test set: all settings opposite (US, English, Imperial, Female, etc.)
        // Can be used for comprehensive testing
    }
}
