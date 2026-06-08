import Foundation

/// Decides what (if anything) the daily HRV reminder should say. Pure function of
/// the day's state: no measurement → gentle nudge; valid measurement → readiness
/// guidance; poor-quality measurement → retake suggestion. One reminder per day.
enum HRVReminderEngine {

    struct Input {
        var date: Date
        var remindersEnabled: Bool
        var includeGuidance: Bool
        var onboardingCompleted: Bool
        /// Today's most recent measurement, if any.
        var latestMeasurementToday: HRVAnalysis?
        var validScanCount: Int

        init(date: Date = .now,
             remindersEnabled: Bool,
             includeGuidance: Bool,
             onboardingCompleted: Bool,
             latestMeasurementToday: HRVAnalysis? = nil,
             validScanCount: Int) {
            self.date = date
            self.remindersEnabled = remindersEnabled
            self.includeGuidance = includeGuidance
            self.onboardingCompleted = onboardingCompleted
            self.latestMeasurementToday = latestMeasurementToday
            self.validScanCount = validScanCount
        }
    }

    enum Priority: String, Sendable { case low, normal }

    struct Output: Equatable {
        var shouldSend: Bool
        var titleKey: String?
        var bodyKey: String?
        var deepLink: String?
        var readiness: HRVReadiness?
        var measurementId: UUID?
        var priority: Priority

        static func silent(_ priority: Priority = .low) -> Output {
            Output(shouldSend: false, titleKey: nil, bodyKey: nil, deepLink: nil,
                   readiness: nil, measurementId: nil, priority: priority)
        }
    }

    static func dailyReminder(_ input: Input) -> Output {
        guard input.remindersEnabled else { return .silent() }

        // No measurement today → nudge a scan.
        guard let measurement = input.latestMeasurementToday else {
            let buildingBaseline = input.validScanCount < HRVConstants.baselineMinScansEarly
            return Output(
                shouldSend: true,
                titleKey: "hrv.reminders.no_measurement.title",
                bodyKey: buildingBaseline
                    ? "hrv.reminders.no_measurement.baseline_building.body"
                    : "hrv.reminders.no_measurement.general.body",
                deepLink: input.onboardingCompleted ? "app://hrv/scan" : "app://hrv/onboarding",
                readiness: nil,
                measurementId: nil,
                priority: .normal)
        }

        // Poor-quality measurement → suggest a retake.
        if measurement.qualityScore < HRVConstants.qualityUsableMin {
            return Output(
                shouldSend: true,
                titleKey: "hrv.reminders.bad_quality.title",
                bodyKey: "hrv.reminders.bad_quality.body",
                deepLink: "app://hrv/scan",
                readiness: nil,
                measurementId: measurement.id,
                priority: .normal)
        }

        // Valid measurement but user opted out of in-reminder guidance → stay quiet.
        guard input.includeGuidance else { return .silent() }

        let readiness = measurement.interpretation.readiness
        return Output(
            shouldSend: true,
            titleKey: "hrv.reminders.with_measurement.\(readiness.rawValue).title",
            bodyKey: "hrv.reminders.with_measurement.\(readiness.rawValue).body",
            deepLink: "app://hrv/result/\(measurement.id.uuidString)",
            readiness: readiness,
            measurementId: measurement.id,
            priority: .normal)
    }
}
