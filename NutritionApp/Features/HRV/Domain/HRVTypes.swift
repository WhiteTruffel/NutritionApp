import Foundation

// MARK: - HRV domain types
//
// Pure value types for the HRV module. Translated from the HRV Implementation
// Pack (originally TypeScript) into Swift idioms: string unions become
// `String`-backed enums, interfaces become `struct`s. Everything here is
// `Sendable` and `Codable` so it can cross actor boundaries and be persisted.
//
// Scientific note: phone-camera HRV is PPG-derived pulse-rate variability. It
// estimates heartbeat timing from fingertip colour changes. It is useful for
// daily trends when measured carefully, but it is not ECG and not a medical
// diagnosis.

enum HRVSource: String, Codable, Sendable, CaseIterable {
    case cameraPPG = "camera_ppg"
    case appleWatch = "apple_watch"
    case chestStrap = "chest_strap"
    case manualImport = "manual_import"
}

enum HRVQualityLabel: String, Codable, Sendable, CaseIterable {
    case excellent, good, usable, weak, invalid
}

enum HRVReadiness: String, Codable, Sendable, CaseIterable {
    case push, normal, maintain, recover, uncertain
}

enum HRVRecoverySignal: String, Codable, Sendable, CaseIterable {
    case veryLow = "very_low"
    case low
    case normal
    case strong
    case unusuallyHigh = "unusually_high"
    case unknown
}

enum HRVStressLoad: String, Codable, Sendable, CaseIterable {
    case calm, balanced, activated, strained, overloaded, unknown
}

enum HRVAutonomicBalance: String, Codable, Sendable, CaseIterable {
    case parasympathetic, balanced, sympathetic, mixed, uncertain
}

enum HRVScanMode: String, Codable, Sendable, CaseIterable {
    case quick, standard, deep
}

enum HRVUserTag: String, Codable, Sendable, CaseIterable {
    case sleepBad = "sleep_bad"
    case caffeine
    case alcohol
    case hardTraining = "hard_training"
    case illness
    case fatigue
    case emotionalStress = "emotional_stress"
    case travel
    case dehydration
    case lateMeal = "late_meal"
}

enum HRVConfidence: String, Codable, Sendable {
    case low, medium, high
}

/// Coarse time-of-day bucket used to keep baseline comparisons fair
/// (an evening reading should not be compared too strongly to a morning one).
enum HRVTimeOfDay: String, Codable, Sendable {
    case morning, afternoon, evening

    init(hour: Int) {
        switch hour {
        case 4..<12:  self = .morning
        case 12..<18: self = .afternoon
        default:      self = .evening
        }
    }

    init(date: Date, calendar: Calendar = .current) {
        self.init(hour: calendar.component(.hour, from: date))
    }
}

enum HRVBaselineStatus: String, Codable, Sendable {
    case none, building, early, medium, ready
}

// MARK: - Metric structs

struct HRVHistogramBin: Codable, Sendable, Equatable {
    var startMs: Double
    var endMs: Double
    var count: Int
    var percentage: Double
}

struct HRVPoincarePoint: Codable, Sendable, Equatable {
    var x: Double
    var y: Double
}

struct HRVTimeDomainMetrics: Codable, Sendable, Equatable {
    var heartRateBpm: Double
    var meanNN: Double
    var medianNN: Double
    var minNN: Double
    var maxNN: Double
    var sdnn: Double
    var rmssd: Double
    var lnRmssd: Double
    var nn50: Int
    var pnn50: Double
    var sdsd: Double
    var cvnn: Double
    var cvsd: Double
}

struct HRVGeometricMetrics: Codable, Sendable, Equatable {
    var modeNN: Double?
    var amo50: Double?
    var mxdmn: Double?
    var triangularIndex: Double?
    var tinn: Double?
    var histogramBins: [HRVHistogramBin]
}

struct HRVNonlinearMetrics: Codable, Sendable, Equatable {
    var sd1: Double?
    var sd2: Double?
    var sd1sd2: Double?
    var poincarePoints: [HRVPoincarePoint]
    var sampleEntropy: Double?
    var approximateEntropy: Double?
    var dfaAlpha1: Double?
    var dfaAlpha2: Double?
}

struct HRVFrequencyDomainMetrics: Codable, Sendable, Equatable {
    var vlfPower: Double? = nil
    var lfPower: Double? = nil
    var hfPower: Double? = nil
    var totalPower: Double? = nil
    var lfHfRatio: Double? = nil
    var lfNorm: Double? = nil
    var hfNorm: Double? = nil
    var available: Bool
    var unavailableReason: String? = nil

    static let unavailable = HRVFrequencyDomainMetrics(
        available: false, unavailableReason: nil)
}

struct HRVArtifactResult: Codable, Sendable, Equatable {
    var rawIntervalsMs: [Double]
    var cleanIntervalsMs: [Double]
    var artifactIndices: [Int]
    var artifactCount: Int
    var artifactPercentage: Double
    var validIntervalsCount: Int
    var rejected: Bool
    var rejectionReason: String?
}

struct HRVQualityResult: Codable, Sendable, Equatable {
    var qualityScore: Int
    var qualityLabel: HRVQualityLabel
    var messages: [String]
}

struct HRVBaselineSnapshot: Codable, Sendable, Equatable {
    var validScanCount: Int

    var rmssd7d: Double? = nil
    var rmssd14d: Double? = nil
    var rmssd30d: Double? = nil

    var lnRmssd7d: Double? = nil
    var lnRmssd14d: Double? = nil
    var lnRmssd30d: Double? = nil

    var hr7d: Double? = nil
    var hr14d: Double? = nil
    var hr30d: Double? = nil

    var sdnn7d: Double? = nil
    var sdnn14d: Double? = nil
    var sdnn30d: Double? = nil

    var robustRmssdMedian30d: Double? = nil
    var robustRmssdMad30d: Double? = nil
    var robustRmssdZScore: Double? = nil

    var baselineStatus: HRVBaselineStatus

    static let empty = HRVBaselineSnapshot(validScanCount: 0, baselineStatus: .none)
}

struct HRVInterpretation: Codable, Sendable, Equatable {
    var readiness: HRVReadiness
    var recoverySignal: HRVRecoverySignal
    var stressLoad: HRVStressLoad
    var autonomicBalance: HRVAutonomicBalance

    var summaryKey: String
    var recommendationKey: String
    var explanationKeys: [String]

    var confidence: HRVConfidence

    /// Human-meaningful drivers (e.g. "rmssd_below_baseline"); localisation keys.
    var contributingFactors: [String]
}

/// Full in-memory analysis result for a single scan. This is the rich object the
/// engine returns; the persisted form is `HRVMeasurementRecord` (a lean SwiftData
/// `@Model` holding the scalar summary plus the clean intervals).
struct HRVAnalysis: Codable, Sendable, Equatable {
    // All members are value types, so this is safely Sendable across actors.
    var id: UUID
    var timestamp: Date
    var source: HRVSource
    var scanMode: HRVScanMode

    var durationSeconds: Double
    var totalBeats: Int
    var validIntervalsCount: Int

    var artifactCount: Int
    var artifactPercentage: Double

    var qualityScore: Int
    var qualityLabel: HRVQualityLabel

    var rawIntervalsMs: [Double]?
    var cleanIntervalsMs: [Double]

    var timeDomain: HRVTimeDomainMetrics
    var geometric: HRVGeometricMetrics
    var nonlinear: HRVNonlinearMetrics
    var frequencyDomain: HRVFrequencyDomainMetrics

    var baseline: HRVBaselineSnapshot?
    var interpretation: HRVInterpretation

    var tags: [HRVUserTag]
}

/// Lightweight, pure baseline input. Decoupled from SwiftData so the baseline
/// engine stays a testable pure function. Built from persisted records.
struct HRVBaselineSample: Codable, Sendable, Equatable {
    var timestamp: Date
    var rmssd: Double
    var lnRmssd: Double
    var heartRateBpm: Double
    var sdnn: Double
    var qualityScore: Int
    var timeOfDay: HRVTimeOfDay
}
