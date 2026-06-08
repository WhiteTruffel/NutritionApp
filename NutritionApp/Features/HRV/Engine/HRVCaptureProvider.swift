import Foundation

/// Result of a capture: the raw intervals plus context the engine needs.
struct HRVCapturedIntervals: Sendable, Equatable {
    var rawIntervalsMs: [Double]
    var durationSeconds: Double
    var source: HRVSource
}

/// Abstraction over "where the beat intervals come from". The real AVFoundation
/// camera-PPG pipeline (torch on, per-frame red-channel averaging, peak detection)
/// will be a follow-up that conforms to this protocol. Today we ship the
/// simulated provider, which lets the entire pipeline run in CI and UI tests with
/// no device and no fingertip.
protocol HRVCaptureProvider {
    func capture(mode: HRVScanMode) async throws -> HRVCapturedIntervals
}

/// Suggested capture duration per scan depth (seconds).
extension HRVScanMode {
    var captureDurationSeconds: Double {
        switch self {
        case .quick:    return HRVConstants.quickScanRecommendedSeconds   // 120
        case .standard: return HRVConstants.standardScanSeconds           // 300
        case .deep:     return HRVConstants.standardScanSeconds + 60       // a bit longer
        }
    }
}

/// Simulated capture source for autonomous testing, previews, and demos.
/// Produces physiologically plausible intervals deterministically (seeded).
struct SimulatedHRVCaptureProvider: HRVCaptureProvider {
    var seed: UInt64
    var profile: String   // "clean" or "noisy"
    /// When true, sleep for the scan duration to mimic real timing. Tests leave
    /// this off so they run instantly.
    var simulateRealTimeDelay: Bool

    init(seed: UInt64 = HRVAutomation.simulatedSeed,
         profile: String = HRVAutomation.simulatedProfile,
         simulateRealTimeDelay: Bool = false) {
        self.seed = seed
        self.profile = profile
        self.simulateRealTimeDelay = simulateRealTimeDelay
    }

    func capture(mode: HRVScanMode) async throws -> HRVCapturedIntervals {
        let beatCount: Int
        let meanHr: Double
        switch mode {
        case .quick:    beatCount = 120; meanHr = 62
        case .standard: beatCount = 320; meanHr = 60
        case .deep:     beatCount = 360; meanHr = 58
        }
        let artifactRate = (profile == "noisy") ? 0.18 : 0.01
        let sdMs = (profile == "noisy") ? 90.0 : 45.0

        let intervals = HRVIntervalSimulator.generate(
            beatCount: beatCount, meanHeartRate: meanHr, sdMs: sdMs,
            artifactRate: artifactRate, seed: seed)
        let durationSeconds = intervals.reduce(0, +) / 1000.0

        if simulateRealTimeDelay {
            try? await Task.sleep(nanoseconds: UInt64(min(durationSeconds, 3) * 1_000_000_000))
        }
        return HRVCapturedIntervals(
            rawIntervalsMs: intervals, durationSeconds: durationSeconds, source: .cameraPPG)
    }
}

/// Runs one scan end to end: capture → analyse. Pure orchestration around the
/// engine, so a test can call it with `SimulatedHRVCaptureProvider` and get a full
/// `HRVAnalysis` exactly as the live app would.
enum HRVScanRunner {
    static func run(provider: any HRVCaptureProvider,
                    mode: HRVScanMode,
                    timestamp: Date = .now,
                    baselineSamples: [HRVBaselineSample] = [],
                    tags: [HRVUserTag] = []) async throws -> HRVAnalysis {
        let captured = try await provider.capture(mode: mode)
        return HRVEngine.analyze(
            rawIntervalsMs: captured.rawIntervalsMs,
            source: captured.source,
            scanMode: mode,
            durationSeconds: captured.durationSeconds,
            timestamp: timestamp,
            baselineSamples: baselineSamples,
            tags: tags)
    }

    /// The provider the app should use for a scan. Automation forces the simulator
    /// so UI/CI runs need no device or fingertip. The iOS Simulator has no usable
    /// camera, so it also falls back to the simulator. On a real device we use the
    /// AVFoundation camera PPG pipeline.
    static func defaultProvider() -> any HRVCaptureProvider {
        if HRVAutomation.simulateScan {
            return SimulatedHRVCaptureProvider(simulateRealTimeDelay: false)
        }
        #if targetEnvironment(simulator)
        return SimulatedHRVCaptureProvider(simulateRealTimeDelay: true)
        #else
        return HRVCameraPPGProvider()
        #endif
    }
}
