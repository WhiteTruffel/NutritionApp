import XCTest
import SwiftData
@testable import NutritionApp

/// End-to-end coverage for fully autonomous testing: a simulated "camera" scan
/// must flow through the real engine, produce a usable analysis, and persist as a
/// record that the baseline engine can later consume. No device or fingertip.
final class HRVScanSimulationTests: XCTestCase {

    func testSimulatedCleanScanRunsEndToEnd() async throws {
        let provider = SimulatedHRVCaptureProvider(seed: 99, profile: "clean")
        let analysis = try await HRVScanRunner.run(provider: provider, mode: .quick)

        XCTAssertFalse(analysis.cleanIntervalsMs.isEmpty)
        XCTAssertGreaterThan(analysis.timeDomain.rmssd, 0)
        XCTAssertGreaterThan(analysis.timeDomain.heartRateBpm, 0)
        XCTAssertGreaterThanOrEqual(analysis.qualityScore, HRVConstants.qualityUsableMin)
        XCTAssertEqual(analysis.source, .cameraPPG)
    }

    func testSimulatedNoisyScanIsNotOverInterpreted() async throws {
        let provider = SimulatedHRVCaptureProvider(seed: 7, profile: "noisy")
        let analysis = try await HRVScanRunner.run(provider: provider, mode: .quick)
        // A noisy scan must not score as a pristine one.
        XCTAssertLessThan(analysis.qualityScore, HRVConstants.qualityExcellentMin)
    }

    func testSimulatedScanIsDeterministicForSeed() async throws {
        let p1 = SimulatedHRVCaptureProvider(seed: 123, profile: "clean")
        let p2 = SimulatedHRVCaptureProvider(seed: 123, profile: "clean")
        let a1 = try await HRVScanRunner.run(provider: p1, mode: .quick)
        let a2 = try await HRVScanRunner.run(provider: p2, mode: .quick)
        XCTAssertEqual(a1.timeDomain.rmssd, a2.timeDomain.rmssd, accuracy: 0.0001)
        XCTAssertEqual(a1.cleanIntervalsMs.count, a2.cleanIntervalsMs.count)
    }

    @MainActor
    func testScanPersistsAndFeedsBaseline() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: HRVMeasurementRecord.self, configurations: config)
        let ctx = container.mainContext

        // Seed 8 simulated daily scans into the store.
        let cal = Calendar.current
        let now = Date()
        for i in 1...8 {
            let provider = SimulatedHRVCaptureProvider(seed: UInt64(1000 + i), profile: "clean")
            let ts = cal.date(byAdding: .day, value: -i, to: now)!
            let analysis = try await HRVScanRunner.run(
                provider: provider, mode: .quick, timestamp: ts)
            ctx.insert(HRVMeasurementRecord(analysis: analysis))
        }
        try ctx.save()

        let records = try ctx.fetch(FetchDescriptor<HRVMeasurementRecord>())
        XCTAssertEqual(records.count, 8)

        let samples = records.baselineSamples()
        let snapshot = HRVBaselineEngine.snapshot(samples: samples, now: now)
        XCTAssertEqual(snapshot.validScanCount, samples.count)
        // 8 valid scans -> "early" baseline maturity.
        XCTAssertEqual(snapshot.baselineStatus, .early)
        XCTAssertNotNil(snapshot.rmssd7d)
    }

    @MainActor
    func testFullAnalysisRoundTripsToRecord() throws {
        let intervals = HRVIntervalSimulator.standardScan(seed: 555)
        let duration = intervals.reduce(0, +) / 1000.0
        let analysis = HRVEngine.analyze(
            rawIntervalsMs: intervals, source: .cameraPPG, scanMode: .standard,
            durationSeconds: duration)
        let record = HRVMeasurementRecord(analysis: analysis)
        XCTAssertEqual(record.id, analysis.id)
        XCTAssertEqual(record.rmssd, analysis.timeDomain.rmssd, accuracy: 0.0001)
        XCTAssertEqual(record.readiness, analysis.interpretation.readiness)
        XCTAssertEqual(record.cleanIntervalsMs.count, analysis.cleanIntervalsMs.count)
    }
}
