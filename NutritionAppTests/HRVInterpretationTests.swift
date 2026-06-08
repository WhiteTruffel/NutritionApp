import XCTest
@testable import NutritionApp

final class HRVInterpretationTests: XCTestCase {

    private func input(rmssd: Double, hr: Double, sdnn: Double, quality: Int,
                       baseline: HRVBaselineSnapshot?, tags: [HRVUserTag] = [])
        -> HRVInterpretationEngine.Input {
        HRVInterpretationEngine.Input(
            timeDomain: HRVTestSupport.timeDomain(rmssd: rmssd, hr: hr, sdnn: sdnn),
            geometric: HRVTestSupport.emptyGeometric(),
            qualityScore: quality,
            qualityLabel: HRVQualityScoring.label(for: quality),
            artifactPercentage: 1,
            durationSeconds: 120,
            baseline: baseline,
            tags: tags)
    }

    func testPoorQualityIsUncertain() {
        let r = HRVInterpretationEngine.interpret(
            input(rmssd: 45, hr: 62, sdnn: 50, quality: 50,
                  baseline: HRVTestSupport.baseline(rmssd30: 45, hr30: 62)))
        XCTAssertEqual(r.readiness, .uncertain)
        XCTAssertEqual(r.confidence, .low)
        XCTAssertEqual(r.summaryKey, "hrv.interpretation.uncertain.bad_quality.summary")
    }

    func testNoBaselineIsConservative() {
        let r = HRVInterpretationEngine.interpret(
            input(rmssd: 45, hr: 62, sdnn: 50, quality: 90, baseline: nil))
        XCTAssertEqual(r.readiness, .uncertain)
        XCTAssertEqual(r.summaryKey, "hrv.interpretation.baseline.none.summary")
        XCTAssertEqual(r.confidence, .low)
    }

    func testLowRecovery() {
        let r = HRVInterpretationEngine.interpret(
            input(rmssd: 25, hr: 78, sdnn: 30, quality: 90,
                  baseline: HRVTestSupport.baseline(rmssd30: 45, hr30: 65, sdnn30: 55)))
        XCTAssertEqual(r.readiness, .recover)
        XCTAssertTrue(r.recoverySignal == .low || r.recoverySignal == .veryLow)
        XCTAssertTrue(r.stressLoad == .strained || r.stressLoad == .overloaded)
        XCTAssertEqual(r.autonomicBalance, .sympathetic)
    }

    func testGoodRecovery() {
        let r = HRVInterpretationEngine.interpret(
            input(rmssd: 50, hr: 63, sdnn: 58, quality: 90,
                  baseline: HRVTestSupport.baseline(rmssd30: 45, hr30: 65, sdnn30: 55)))
        XCTAssertTrue(r.readiness == .normal || r.readiness == .push)
        XCTAssertTrue(r.recoverySignal == .normal || r.recoverySignal == .strong)
        XCTAssertTrue(r.stressLoad == .balanced || r.stressLoad == .calm)
    }

    func testHighHRVWithFatigueDoesNotPush() {
        let r = HRVInterpretationEngine.interpret(
            input(rmssd: 80, hr: 60, sdnn: 70, quality: 90,
                  baseline: HRVTestSupport.baseline(rmssd30: 45, hr30: 62),
                  tags: [.fatigue]))
        XCTAssertEqual(r.recoverySignal, .unusuallyHigh)
        XCTAssertNotEqual(r.readiness, .push)
        XCTAssertEqual(r.recommendationKey, "hrv.interpretation.high_hrv_fatigue.recommendation")
    }

    func testHighHRVWithoutFatigueIsPositive() {
        let r = HRVInterpretationEngine.interpret(
            input(rmssd: 80, hr: 60, sdnn: 70, quality: 90,
                  baseline: HRVTestSupport.baseline(rmssd30: 45, hr30: 62)))
        XCTAssertEqual(r.recoverySignal, .strong)
        XCTAssertTrue(r.readiness == .push || r.readiness == .normal)
    }

    func testNormalBalanced() {
        let r = HRVInterpretationEngine.interpret(
            input(rmssd: 46, hr: 63, sdnn: 54, quality: 90,
                  baseline: HRVTestSupport.baseline(rmssd30: 45, hr30: 64, sdnn30: 55)))
        XCTAssertEqual(r.readiness, .normal)
        XCTAssertEqual(r.autonomicBalance, .balanced)
    }
}
