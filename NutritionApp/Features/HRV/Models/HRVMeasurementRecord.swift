import Foundation
import SwiftData

/// Persisted summary of one HRV scan. Deliberately lean: it stores the scalar
/// fields the baseline/interpretation engines need plus the clean intervals (for
/// optional re-analysis), rather than the deeply nested `HRVAnalysis` struct,
/// which keeps the SwiftData schema simple and migration-friendly.
@Model
final class HRVMeasurementRecord {
    @Attribute(.unique) var id: UUID
    var timestamp: Date

    // Raw enum values stored as strings for schema stability.
    var sourceRaw: String
    var scanModeRaw: String

    var durationSeconds: Double
    var totalBeats: Int
    var validIntervalsCount: Int
    var artifactCount: Int
    var artifactPercentage: Double

    var qualityScore: Int
    var qualityLabelRaw: String

    // Headline time-domain values used for baselines and trends.
    var heartRateBpm: Double
    var meanNN: Double
    var sdnn: Double
    var rmssd: Double
    var lnRmssd: Double
    var pnn50: Double

    // Interpretation snapshot.
    var readinessRaw: String
    var recoverySignalRaw: String
    var stressLoadRaw: String
    var autonomicBalanceRaw: String
    var interpretationSummaryKey: String
    var interpretationRecommendationKey: String

    // Clean intervals for re-analysis (ms). Optional to keep records compact.
    var cleanIntervalsMs: [Double]

    // User context tags (raw values).
    var tagRaws: [String]

    init(id: UUID,
         timestamp: Date,
         sourceRaw: String,
         scanModeRaw: String,
         durationSeconds: Double,
         totalBeats: Int,
         validIntervalsCount: Int,
         artifactCount: Int,
         artifactPercentage: Double,
         qualityScore: Int,
         qualityLabelRaw: String,
         heartRateBpm: Double,
         meanNN: Double,
         sdnn: Double,
         rmssd: Double,
         lnRmssd: Double,
         pnn50: Double,
         readinessRaw: String,
         recoverySignalRaw: String,
         stressLoadRaw: String,
         autonomicBalanceRaw: String,
         interpretationSummaryKey: String,
         interpretationRecommendationKey: String,
         cleanIntervalsMs: [Double],
         tagRaws: [String]) {
        self.id = id
        self.timestamp = timestamp
        self.sourceRaw = sourceRaw
        self.scanModeRaw = scanModeRaw
        self.durationSeconds = durationSeconds
        self.totalBeats = totalBeats
        self.validIntervalsCount = validIntervalsCount
        self.artifactCount = artifactCount
        self.artifactPercentage = artifactPercentage
        self.qualityScore = qualityScore
        self.qualityLabelRaw = qualityLabelRaw
        self.heartRateBpm = heartRateBpm
        self.meanNN = meanNN
        self.sdnn = sdnn
        self.rmssd = rmssd
        self.lnRmssd = lnRmssd
        self.pnn50 = pnn50
        self.readinessRaw = readinessRaw
        self.recoverySignalRaw = recoverySignalRaw
        self.stressLoadRaw = stressLoadRaw
        self.autonomicBalanceRaw = autonomicBalanceRaw
        self.interpretationSummaryKey = interpretationSummaryKey
        self.interpretationRecommendationKey = interpretationRecommendationKey
        self.cleanIntervalsMs = cleanIntervalsMs
        self.tagRaws = tagRaws
    }

    /// Build a persisted record from a full analysis result.
    convenience init(analysis a: HRVAnalysis) {
        self.init(
            id: a.id,
            timestamp: a.timestamp,
            sourceRaw: a.source.rawValue,
            scanModeRaw: a.scanMode.rawValue,
            durationSeconds: a.durationSeconds,
            totalBeats: a.totalBeats,
            validIntervalsCount: a.validIntervalsCount,
            artifactCount: a.artifactCount,
            artifactPercentage: a.artifactPercentage,
            qualityScore: a.qualityScore,
            qualityLabelRaw: a.qualityLabel.rawValue,
            heartRateBpm: a.timeDomain.heartRateBpm,
            meanNN: a.timeDomain.meanNN,
            sdnn: a.timeDomain.sdnn,
            rmssd: a.timeDomain.rmssd,
            lnRmssd: a.timeDomain.lnRmssd,
            pnn50: a.timeDomain.pnn50,
            readinessRaw: a.interpretation.readiness.rawValue,
            recoverySignalRaw: a.interpretation.recoverySignal.rawValue,
            stressLoadRaw: a.interpretation.stressLoad.rawValue,
            autonomicBalanceRaw: a.interpretation.autonomicBalance.rawValue,
            interpretationSummaryKey: a.interpretation.summaryKey,
            interpretationRecommendationKey: a.interpretation.recommendationKey,
            cleanIntervalsMs: a.cleanIntervalsMs,
            tagRaws: a.tags.map { $0.rawValue })
    }

    /// Lightweight, pure value for the baseline engine.
    var baselineSample: HRVBaselineSample {
        HRVBaselineSample(
            timestamp: timestamp,
            rmssd: rmssd,
            lnRmssd: lnRmssd,
            heartRateBpm: heartRateBpm,
            sdnn: sdnn,
            qualityScore: qualityScore,
            timeOfDay: HRVTimeOfDay(date: timestamp))
    }

    var qualityLabel: HRVQualityLabel { HRVQualityLabel(rawValue: qualityLabelRaw) ?? .invalid }
    var readiness: HRVReadiness { HRVReadiness(rawValue: readinessRaw) ?? .uncertain }
}

extension Array where Element == HRVMeasurementRecord {
    /// Baseline samples from valid (usable+) scans only, excluding a given id.
    func baselineSamples(excluding excludedId: UUID? = nil) -> [HRVBaselineSample] {
        self.filter { $0.qualityScore >= HRVConstants.qualityUsableMin && $0.id != excludedId }
            .map { $0.baselineSample }
    }
}
