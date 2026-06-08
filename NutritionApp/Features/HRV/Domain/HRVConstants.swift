import Foundation

/// Central tunable constants for the HRV module. Kept in one place so thresholds
/// are easy to audit and adjust. Values mirror the HRV Implementation Pack.
enum HRVConstants {
    // Physiological plausibility bounds for an RR/NN interval (ms).
    static let minPhysiologicalIntervalMs: Double = 300
    static let maxPhysiologicalIntervalMs: Double = 2000

    // Local-median artifact rejection: relative deviation above which a beat is
    // treated as an artifact.
    static let artifactLocalMedianThreshold: Double = 0.25
    // Half-width of the local window used for median comparison (window = 2*W+1).
    static let artifactWindowHalfWidth: Int = 2
    // A scan is rejected outright below this many clean intervals or above this
    // artifact percentage.
    static let minCleanIntervalsForValidScan: Int = 30
    static let maxArtifactPercentageForValidScan: Double = 20

    // Histogram bin width (ms) for geometric metrics.
    static let histogramBinSizeMs: Double = 50
    // Triangular index needs a reasonable number of beats to be meaningful.
    static let triangularIndexMinBeats: Int = 60

    // Quality score thresholds → labels.
    static let qualityExcellentMin: Int = 90
    static let qualityGoodMin: Int = 75
    static let qualityUsableMin: Int = 60
    static let qualityWeakMin: Int = 40

    // Frequency-domain gating.
    static let frequencyMinDurationSeconds: Double = 300
    static let frequencyMinCleanBeats: Int = 300
    static let frequencyMaxArtifactPercentage: Double = 5
    static let frequencyMinQualityScore: Int = 75

    // Spectral band edges (Hz). Reserved for a real PSD implementation; we never
    // fabricate band powers without one.
    static let vlfMinHz: Double = 0.0033
    static let vlfMaxHz: Double = 0.04
    static let lfMinHz: Double = 0.04
    static let lfMaxHz: Double = 0.15
    static let hfMinHz: Double = 0.15
    static let hfMaxHz: Double = 0.4

    // Scan-mode durations.
    static let quickScanMinSeconds: Double = 60
    static let quickScanRecommendedSeconds: Double = 120
    static let standardScanSeconds: Double = 300
    static let deepScanMinCleanBeats: Int = 300

    // Baseline maturity thresholds (number of valid scans).
    static let baselineMinScansBuilding: Int = 3
    static let baselineMinScansEarly: Int = 7
    static let baselineMinScansMedium: Int = 14
    static let baselineMinScansReady: Int = 30

    // Interpretation deviation thresholds (percent vs baseline).
    static let rmssdMildDropPercent: Double = -10
    static let rmssdStrongDropPercent: Double = -25
    static let rmssdElevatedPercent: Double = 10
    static let rmssdUnusuallyHighPercent: Double = 25
    static let hrMildRisePercent: Double = 5
    static let hrStrongRisePercent: Double = 10
    static let veryLowRmssdDropPercent: Double = -35
}
