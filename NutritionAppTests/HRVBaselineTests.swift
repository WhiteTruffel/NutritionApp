import XCTest
@testable import NutritionApp

final class HRVBaselineTests: XCTestCase {

    func testStatusThresholds() {
        XCTAssertEqual(HRVBaselineEngine.status(validScanCount: 0), .none)
        XCTAssertEqual(HRVBaselineEngine.status(validScanCount: 2), .none)
        XCTAssertEqual(HRVBaselineEngine.status(validScanCount: 3), .building)
        XCTAssertEqual(HRVBaselineEngine.status(validScanCount: 7), .early)
        XCTAssertEqual(HRVBaselineEngine.status(validScanCount: 14), .medium)
        XCTAssertEqual(HRVBaselineEngine.status(validScanCount: 30), .ready)
    }

    func testEmptyHistory() {
        let snap = HRVBaselineEngine.snapshot(samples: [], now: .now)
        XCTAssertEqual(snap.baselineStatus, .none)
        XCTAssertNil(snap.rmssd30d)
        XCTAssertEqual(snap.validScanCount, 0)
    }

    func testRollingMediansAndRobustZScore() {
        let now = Date()
        let cal = Calendar.current
        let rmssds: [Double] = [30, 40, 50, 60, 70]   // median 50, MAD 10
        let samples: [HRVBaselineSample] = rmssds.enumerated().map { i, r in
            HRVBaselineSample(
                timestamp: cal.date(byAdding: .day, value: -(i + 1), to: now)!,
                rmssd: r, lnRmssd: Foundation.log(r), heartRateBpm: 60, sdnn: 55,
                qualityScore: 90, timeOfDay: .morning)
        }
        let snap = HRVBaselineEngine.snapshot(samples: samples, now: now, currentRmssd: 80)
        XCTAssertEqual(snap.validScanCount, 5)
        XCTAssertEqual(snap.baselineStatus, .building)
        XCTAssertEqual(snap.rmssd7d ?? -1, 50, accuracy: 0.0001)
        XCTAssertEqual(snap.rmssd30d ?? -1, 50, accuracy: 0.0001)
        XCTAssertEqual(snap.robustRmssdMedian30d ?? -1, 50, accuracy: 0.0001)
        XCTAssertEqual(snap.robustRmssdMad30d ?? -1, 10, accuracy: 0.0001)
        // z = (80 - 50) / (1.4826 * 10) ~ 2.02
        XCTAssertEqual(snap.robustRmssdZScore ?? 0, 2.0235, accuracy: 0.01)
    }

    func testTimeOfDayPreferenceWhenEnoughSamples() {
        let now = Date()
        let cal = Calendar.current
        func sample(daysAgo: Int, rmssd: Double, tod: HRVTimeOfDay) -> HRVBaselineSample {
            HRVBaselineSample(
                timestamp: cal.date(byAdding: .day, value: -daysAgo, to: now)!,
                rmssd: rmssd, lnRmssd: Foundation.log(rmssd), heartRateBpm: 60, sdnn: 55,
                qualityScore: 90, timeOfDay: tod)
        }
        // 4 morning samples (rmssd 40) and 4 evening samples (rmssd 80).
        var samples: [HRVBaselineSample] = []
        for i in 1...4 { samples.append(sample(daysAgo: i, rmssd: 40, tod: .morning)) }
        for i in 5...8 { samples.append(sample(daysAgo: i, rmssd: 80, tod: .evening)) }

        let morning = HRVBaselineEngine.snapshot(samples: samples, now: now, preferredTimeOfDay: .morning)
        XCTAssertEqual(morning.rmssd30d ?? -1, 40, accuracy: 0.0001)   // morning-only

        let unfiltered = HRVBaselineEngine.snapshot(samples: samples, now: now, preferredTimeOfDay: nil)
        XCTAssertEqual(unfiltered.rmssd30d ?? -1, 60, accuracy: 0.0001) // median of all
    }
}
