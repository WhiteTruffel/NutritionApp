import XCTest
@testable import NutritionApp

final class HRVFrequencyGatingTests: XCTestCase {

    func testShortScanGatedOut() {
        let gate = HRVFrequencyDomain.canCalculate(.init(
            durationSeconds: 60, validIntervalsCount: 100, qualityScore: 90, artifactPercentage: 1))
        XCTAssertFalse(gate.available)
        XCTAssertEqual(gate.reason, "frequency_requires_longer_scan")
    }

    func testLongCleanScanGatedIn() {
        let gate = HRVFrequencyDomain.canCalculate(.init(
            durationSeconds: 300, validIntervalsCount: 300, qualityScore: 90, artifactPercentage: 2))
        XCTAssertTrue(gate.available)
        XCTAssertNil(gate.reason)
    }

    func testLowQualityGatedOut() {
        let gate = HRVFrequencyDomain.canCalculate(.init(
            durationSeconds: 300, validIntervalsCount: 300, qualityScore: 55, artifactPercentage: 2))
        XCTAssertFalse(gate.available)
        XCTAssertEqual(gate.reason, "frequency_requires_better_quality")
    }

    func testTooManyArtifactsGatedOut() {
        let gate = HRVFrequencyDomain.canCalculate(.init(
            durationSeconds: 300, validIntervalsCount: 300, qualityScore: 90, artifactPercentage: 9))
        XCTAssertFalse(gate.available)
        XCTAssertEqual(gate.reason, "frequency_too_many_artifacts")
    }

    func testNoFakeValuesEvenWhenGateOpen() {
        // Gate is open, but without a real PSD implementation we must not invent
        // band powers; the result is explicitly unavailable.
        let m = HRVFrequencyDomain.metrics(
            intervalsMs: Array(repeating: 1000, count: 300),
            durationSeconds: 300, qualityScore: 90, artifactPercentage: 2)
        XCTAssertFalse(m.available)
        XCTAssertEqual(m.unavailableReason, "frequency_not_implemented_yet")
        XCTAssertNil(m.lfPower)
        XCTAssertNil(m.hfPower)
        XCTAssertNil(m.lfHfRatio)
    }
}
