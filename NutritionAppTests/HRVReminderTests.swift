import XCTest
@testable import NutritionApp

final class HRVReminderTests: XCTestCase {

    func testRemindersDisabled() {
        let out = HRVReminderEngine.dailyReminder(.init(
            remindersEnabled: false, includeGuidance: true, onboardingCompleted: true,
            latestMeasurementToday: nil, validScanCount: 10))
        XCTAssertFalse(out.shouldSend)
    }

    func testNoMeasurementNudgesScan() {
        let out = HRVReminderEngine.dailyReminder(.init(
            remindersEnabled: true, includeGuidance: true, onboardingCompleted: true,
            latestMeasurementToday: nil, validScanCount: 10))
        XCTAssertTrue(out.shouldSend)
        XCTAssertEqual(out.titleKey, "hrv.reminders.no_measurement.title")
        XCTAssertEqual(out.bodyKey, "hrv.reminders.no_measurement.general.body")
        XCTAssertEqual(out.deepLink, "app://hrv/scan")
    }

    func testNoMeasurementBaselineBuildingRoutesToOnboarding() {
        let out = HRVReminderEngine.dailyReminder(.init(
            remindersEnabled: true, includeGuidance: true, onboardingCompleted: false,
            latestMeasurementToday: nil, validScanCount: 2))
        XCTAssertEqual(out.bodyKey, "hrv.reminders.no_measurement.baseline_building.body")
        XCTAssertEqual(out.deepLink, "app://hrv/onboarding")
    }

    func testMeasuredPushGivesGuidance() {
        let measurement = HRVTestSupport.analysis(qualityScore: 88, readiness: .push)
        let out = HRVReminderEngine.dailyReminder(.init(
            remindersEnabled: true, includeGuidance: true, onboardingCompleted: true,
            latestMeasurementToday: measurement, validScanCount: 30))
        XCTAssertTrue(out.shouldSend)
        XCTAssertEqual(out.readiness, .push)
        XCTAssertEqual(out.titleKey, "hrv.reminders.with_measurement.push.title")
        XCTAssertEqual(out.deepLink, "app://hrv/result/\(measurement.id.uuidString)")
    }

    func testMeasuredRecoverGivesGuidance() {
        let measurement = HRVTestSupport.analysis(qualityScore: 85, readiness: .recover)
        let out = HRVReminderEngine.dailyReminder(.init(
            remindersEnabled: true, includeGuidance: true, onboardingCompleted: true,
            latestMeasurementToday: measurement, validScanCount: 30))
        XCTAssertEqual(out.bodyKey, "hrv.reminders.with_measurement.recover.body")
    }

    func testPoorQualityMeasurementSuggestsRetake() {
        let measurement = HRVTestSupport.analysis(qualityScore: 50, readiness: .uncertain)
        let out = HRVReminderEngine.dailyReminder(.init(
            remindersEnabled: true, includeGuidance: true, onboardingCompleted: true,
            latestMeasurementToday: measurement, validScanCount: 30))
        XCTAssertEqual(out.titleKey, "hrv.reminders.bad_quality.title")
        XCTAssertEqual(out.deepLink, "app://hrv/scan")
    }

    func testGuidanceOptOutStaysSilentForGoodScan() {
        let measurement = HRVTestSupport.analysis(qualityScore: 88, readiness: .normal)
        let out = HRVReminderEngine.dailyReminder(.init(
            remindersEnabled: true, includeGuidance: false, onboardingCompleted: true,
            latestMeasurementToday: measurement, validScanCount: 30))
        XCTAssertFalse(out.shouldSend)
    }
}
