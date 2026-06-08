import Foundation
@testable import NutritionApp

/// Shared builders for the HRV test suite.
enum HRVTestSupport {

    /// Build a time-domain metric set with the fields the interpretation engine
    /// reads; the rest are filled with consistent placeholder values.
    static func timeDomain(rmssd: Double, hr: Double, sdnn: Double, pnn50: Double = 0)
        -> HRVTimeDomainMetrics {
        let meanNN = hr > 0 ? 60000 / hr : 0
        return HRVTimeDomainMetrics(
            heartRateBpm: hr,
            meanNN: meanNN,
            medianNN: meanNN,
            minNN: meanNN,
            maxNN: meanNN,
            sdnn: sdnn,
            rmssd: rmssd,
            lnRmssd: rmssd > 0 ? log(rmssd) : 0,
            nn50: 0,
            pnn50: pnn50,
            sdsd: 0,
            cvnn: 0,
            cvsd: 0)
    }

    static func emptyGeometric() -> HRVGeometricMetrics {
        HRVGeometricMetrics(modeNN: nil, amo50: nil, mxdmn: nil,
                            triangularIndex: nil, tinn: nil, histogramBins: [])
    }

    /// A ready baseline snapshot with the given 30-day medians.
    static func baseline(rmssd30: Double, hr30: Double, sdnn30: Double? = nil,
                         status: HRVBaselineStatus = .ready, count: Int = 30)
        -> HRVBaselineSnapshot {
        var b = HRVBaselineSnapshot.empty
        b.validScanCount = count
        b.baselineStatus = status
        b.rmssd30d = rmssd30
        b.lnRmssd30d = rmssd30 > 0 ? log(rmssd30) : nil
        b.hr30d = hr30
        b.sdnn30d = sdnn30
        b.robustRmssdMedian30d = rmssd30
        return b
    }

    /// Build a full analysis object with a chosen quality score and readiness,
    /// for the reminder engine tests.
    static func analysis(qualityScore: Int,
                         readiness: HRVReadiness,
                         id: UUID = UUID(),
                         timestamp: Date = .now) -> HRVAnalysis {
        let td = timeDomain(rmssd: 45, hr: 62, sdnn: 50)
        let interp = HRVInterpretation(
            readiness: readiness,
            recoverySignal: .normal,
            stressLoad: .balanced,
            autonomicBalance: .balanced,
            summaryKey: "hrv.interpretation.normal.summary",
            recommendationKey: "hrv.interpretation.normal.recommendation",
            explanationKeys: [],
            confidence: .high,
            contributingFactors: [])
        return HRVAnalysis(
            id: id, timestamp: timestamp, source: .cameraPPG, scanMode: .quick,
            durationSeconds: 120, totalBeats: 120, validIntervalsCount: 118,
            artifactCount: 2, artifactPercentage: 1.7,
            qualityScore: qualityScore, qualityLabel: HRVQualityScoring.label(for: qualityScore),
            rawIntervalsMs: nil, cleanIntervalsMs: [],
            timeDomain: td, geometric: emptyGeometric(),
            nonlinear: HRVNonlinearMetrics(sd1: nil, sd2: nil, sd1sd2: nil, poincarePoints: [],
                                           sampleEntropy: nil, approximateEntropy: nil,
                                           dfaAlpha1: nil, dfaAlpha2: nil),
            frequencyDomain: .unavailable,
            baseline: nil, interpretation: interp, tags: [])
    }
}
