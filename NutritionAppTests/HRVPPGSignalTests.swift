import XCTest
@testable import NutritionApp

/// Unit tests for the pure PPG signal processor. The camera itself cannot run in
/// the simulator, so we validate the brightness-to-intervals math with synthetic
/// waveforms that mimic a fingertip pulse (a cosine on a bright DC offset).
final class HRVPPGSignalTests: XCTestCase {

    /// Build a synthetic PPG-like waveform at `bpm`, sampled at `fs` for `seconds`.
    private func synthetic(bpm: Double, fs: Double, seconds: Double,
                           dc: Double = 180, amplitude: Double = 12)
        -> (brightness: [Double], timestamps: [Double]) {
        let n = Int(fs * seconds)
        let freq = bpm / 60.0
        var brightness: [Double] = []
        var timestamps: [Double] = []
        for i in 0..<n {
            let t = Double(i) / fs
            brightness.append(dc + amplitude * cos(2 * Double.pi * freq * t))
            timestamps.append(t)
        }
        return (brightness, timestamps)
    }

    func testSixtyBpmGivesAboutOneSecondIntervals() {
        let (b, t) = synthetic(bpm: 60, fs: 30, seconds: 12)
        let intervals = HRVPPGSignalProcessor.intervalsMs(brightness: b, timestamps: t)
        XCTAssertGreaterThanOrEqual(intervals.count, 9)
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        XCTAssertEqual(mean, 1000, accuracy: 60)   // ~1000 ms per beat
    }

    func testNinetyBpmGivesAboutSixSeventyMsIntervals() {
        let (b, t) = synthetic(bpm: 90, fs: 30, seconds: 12)
        let intervals = HRVPPGSignalProcessor.intervalsMs(brightness: b, timestamps: t)
        XCTAssertGreaterThanOrEqual(intervals.count, 14)
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        XCTAssertEqual(mean, 667, accuracy: 50)
    }

    func testEndToEndThroughEngineProducesValidHeartRate() {
        let (b, t) = synthetic(bpm: 60, fs: 30, seconds: 20)
        let intervals = HRVPPGSignalProcessor.intervalsMs(brightness: b, timestamps: t)
        let analysis = HRVEngine.analyze(
            rawIntervalsMs: intervals, source: .cameraPPG, scanMode: .quick,
            durationSeconds: 20)
        XCTAssertEqual(analysis.timeDomain.heartRateBpm, 60, accuracy: 5)
    }

    func testFlatSignalYieldsNoIntervals() {
        let n = 300
        let brightness = [Double](repeating: 180, count: n)
        let timestamps = (0..<n).map { Double($0) / 30.0 }
        XCTAssertTrue(HRVPPGSignalProcessor.intervalsMs(brightness: brightness, timestamps: timestamps).isEmpty)
    }

    func testTooShortInputYieldsNoIntervals() {
        XCTAssertTrue(HRVPPGSignalProcessor.intervalsMs(brightness: [1, 2, 3], timestamps: [0, 0.1, 0.2]).isEmpty)
    }

    func testPeakDetectionRespectsRefractoryDistance() {
        // Two close spikes within the refractory window collapse to the larger.
        var x = [Double](repeating: 0, count: 20)
        x[5] = 1.0
        x[6] = 2.0   // larger, within minDistance of index 5
        x[15] = 1.5
        let peaks = HRVPPGSignalProcessor.detectPeaks(x, threshold: 0.5, minDistance: 5)
        XCTAssertEqual(peaks, [6, 15])
    }
}
