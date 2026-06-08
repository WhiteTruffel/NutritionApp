import XCTest
@testable import NutritionApp

/// Time-domain, geometric, and nonlinear metric tests.
final class HRVMetricsTests: XCTestCase {

    func testConstantIntervals() {
        let m = HRVTimeDomain.metrics([1000, 1000, 1000, 1000, 1000])
        XCTAssertEqual(m.heartRateBpm, 60, accuracy: 0.0001)
        XCTAssertEqual(m.meanNN, 1000, accuracy: 0.0001)
        XCTAssertEqual(m.sdnn, 0, accuracy: 0.0001)
        XCTAssertEqual(m.rmssd, 0, accuracy: 0.0001)
        XCTAssertEqual(m.nn50, 0)
        XCTAssertEqual(m.pnn50, 0, accuracy: 0.0001)
        XCTAssertEqual(m.cvnn, 0, accuracy: 0.0001)
    }

    func testMildVariability() {
        let m = HRVTimeDomain.metrics([1000, 1020, 980, 1010, 990])
        XCTAssertEqual(m.meanNN, 1000, accuracy: 0.5)
        XCTAssertEqual(m.heartRateBpm, 60, accuracy: 0.5)
        XCTAssertGreaterThan(m.sdnn, 0)
        XCTAssertGreaterThan(m.rmssd, 0)
        XCTAssertEqual(m.pnn50, 0, accuracy: 0.0001)   // no successive diff > 50 ms
    }

    func testPnn50() {
        let m = HRVTimeDomain.metrics([1000, 1060, 1000, 1070, 1000])
        XCTAssertEqual(m.nn50, 4)
        XCTAssertEqual(m.pnn50, 100, accuracy: 0.0001)
    }

    func testRmssdKnownValue() {
        // diffs = [100, -100]; mean square = 10000; rmssd = 100.
        XCTAssertEqual(HRVTimeDomain.rmssd([1000, 1100, 1000]), 100, accuracy: 0.0001)
    }

    func testGeometricHistogramAndIndices() {
        let intervals = Array(repeating: 1000.0, count: 80) + [1040, 960, 1010, 990]
        let g = HRVGeometry.metrics(intervals)
        XCTAssertFalse(g.histogramBins.isEmpty)
        // Mode bin centre should sit on the dominant 1000 ms cluster.
        XCTAssertNotNil(g.modeNN)
        XCTAssertEqual(g.modeNN ?? 0, 1025, accuracy: 50)
        XCTAssertNotNil(g.mxdmn)
        XCTAssertEqual(g.mxdmn ?? 0, 80, accuracy: 0.0001)   // 1040 - 960
        // Enough beats for triangular index.
        XCTAssertNotNil(g.triangularIndex)
    }

    func testTriangularIndexNilForShortScan() {
        let g = HRVGeometry.metrics([1000, 1010, 990])
        XCTAssertNil(g.triangularIndex)   // < 60 beats
    }

    func testNonlinearSD1SD2() {
        let intervals: [Double] = [1000, 1040, 980, 1020, 990, 1010]
        let td = HRVTimeDomain.metrics(intervals)
        let nl = HRVNonlinear.metrics(intervals, sdnn: td.sdnn, rmssd: td.rmssd)
        XCTAssertEqual(nl.sd1 ?? -1, td.rmssd / 2.0.squareRoot(), accuracy: 0.0001)
        XCTAssertEqual(nl.poincarePoints.count, intervals.count - 1)
        if let sd2 = nl.sd2 { XCTAssertGreaterThanOrEqual(sd2, 0) }
    }

    func testStatisticsHelpers() {
        XCTAssertEqual(HRVStatistics.median([3, 1, 2]), 2, accuracy: 0.0001)
        XCTAssertEqual(HRVStatistics.median([4, 1, 2, 3]), 2.5, accuracy: 0.0001)
        XCTAssertEqual(HRVStatistics.mean([2, 4, 6]), 4, accuracy: 0.0001)
        // Sample standard deviation of [2,4,6]: var = ((4)+(0)+(4))/2 = 4 -> sd 2.
        XCTAssertEqual(HRVStatistics.standardDeviation([2, 4, 6]), 2, accuracy: 0.0001)
        XCTAssertEqual(HRVStatistics.medianAbsoluteDeviation([1, 2, 3, 4, 5]), 1, accuracy: 0.0001)
    }
}
