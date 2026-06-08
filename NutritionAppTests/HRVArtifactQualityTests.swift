import XCTest
@testable import NutritionApp

final class HRVArtifactQualityTests: XCTestCase {

    func testLocalMedianArtifactFlagged() {
        let result = HRVArtifactDetection.clean([1000, 1010, 995, 480, 1005, 1015])
        XCTAssertEqual(result.artifactCount, 1)
        XCTAssertTrue(result.artifactIndices.contains(3))   // the 480 ms outlier
        // Quality is reduced relative to a perfect scan.
        let q = HRVQualityScoring.score(HRVQualityScoring.Input(
            artifactPercentage: result.artifactPercentage,
            validIntervalsCount: result.validIntervalsCount,
            durationSeconds: 30,
            rejected: result.rejected))
        XCTAssertLessThan(q.qualityScore, 100)
    }

    func testNonPhysiologicalRejectedScan() {
        let result = HRVArtifactDetection.clean([1000, 1005, 250, 1010, 3000])
        XCTAssertTrue(result.artifactIndices.contains(2))   // 250 ms too short
        XCTAssertTrue(result.artifactIndices.contains(4))   // 3000 ms too long
        XCTAssertTrue(result.rejected)                       // too few clean intervals
    }

    func testCleanScanNotRejected() {
        let intervals = HRVIntervalSimulator.generate(
            beatCount: 120, meanHeartRate: 60, sdMs: 40, artifactRate: 0, seed: 42)
        let result = HRVArtifactDetection.clean(intervals)
        XCTAssertFalse(result.rejected)
        XCTAssertGreaterThanOrEqual(result.validIntervalsCount, 30)
    }

    func testQualityLabels() {
        XCTAssertEqual(HRVQualityScoring.label(for: 95), .excellent)
        XCTAssertEqual(HRVQualityScoring.label(for: 80), .good)
        XCTAssertEqual(HRVQualityScoring.label(for: 65), .usable)
        XCTAssertEqual(HRVQualityScoring.label(for: 45), .weak)
        XCTAssertEqual(HRVQualityScoring.label(for: 20), .invalid)
    }

    func testHighArtifactShortScanYieldsWeakOrInvalid() {
        let q = HRVQualityScoring.score(HRVQualityScoring.Input(
            artifactPercentage: 18, validIntervalsCount: 40, durationSeconds: 50, rejected: false))
        // 100 - 35 (artifacts) - 20 (short) - 20 (too short) = 25 -> invalid.
        XCTAssertLessThanOrEqual(q.qualityScore, HRVConstants.qualityWeakMin)
        XCTAssertTrue(q.qualityLabel == .weak || q.qualityLabel == .invalid)
    }

    func testRejectedInputScoresInvalid() {
        let q = HRVQualityScoring.score(HRVQualityScoring.Input(
            artifactPercentage: 0, validIntervalsCount: 10, durationSeconds: 120, rejected: true))
        XCTAssertEqual(q.qualityLabel, .invalid)
        XCTAssertEqual(q.messages, ["hrv.quality.message.rejected"])
    }
}
