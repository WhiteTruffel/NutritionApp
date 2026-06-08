import Foundation

/// Orchestrator that turns raw RR/NN intervals into a complete `HRVAnalysis`.
/// Composes the pure sub-engines in order: clean → quality → metrics → baseline →
/// interpretation. Pure and synchronous, so it is trivially testable.
enum HRVEngine {

    /// Analyse a single scan.
    /// - Parameters:
    ///   - rawIntervalsMs: raw beat-to-beat intervals (ms) as captured/imported.
    ///   - source: capture source.
    ///   - scanMode: requested depth.
    ///   - durationSeconds: wall-clock duration of the capture.
    ///   - timestamp: when the scan was taken.
    ///   - id: stable identifier (defaults to a fresh UUID).
    ///   - baselineSamples: prior valid scans (this scan excluded).
    ///   - tags: user-supplied context tags.
    static func analyze(rawIntervalsMs: [Double],
                        source: HRVSource,
                        scanMode: HRVScanMode,
                        durationSeconds: Double,
                        timestamp: Date = .now,
                        id: UUID = UUID(),
                        baselineSamples: [HRVBaselineSample] = [],
                        tags: [HRVUserTag] = []) -> HRVAnalysis {

        let artifact = HRVArtifactDetection.clean(rawIntervalsMs)

        let quality = HRVQualityScoring.score(HRVQualityScoring.Input(
            artifactPercentage: artifact.artifactPercentage,
            validIntervalsCount: artifact.validIntervalsCount,
            durationSeconds: durationSeconds,
            rejected: artifact.rejected))

        let clean = artifact.cleanIntervalsMs

        // Degenerate case: no usable intervals at all.
        guard !clean.isEmpty else {
            return rejectedAnalysis(
                id: id, timestamp: timestamp, source: source, scanMode: scanMode,
                durationSeconds: durationSeconds, artifact: artifact, quality: quality, tags: tags)
        }

        let timeDomain = HRVTimeDomain.metrics(clean)
        let geometric = HRVGeometry.metrics(clean)
        let nonlinear = HRVNonlinear.metrics(clean, sdnn: timeDomain.sdnn, rmssd: timeDomain.rmssd)
        let frequency = HRVFrequencyDomain.metrics(
            intervalsMs: clean,
            durationSeconds: durationSeconds,
            qualityScore: quality.qualityScore,
            artifactPercentage: artifact.artifactPercentage)

        let baseline = HRVBaselineEngine.snapshot(
            samples: baselineSamples,
            now: timestamp,
            preferredTimeOfDay: HRVTimeOfDay(date: timestamp),
            currentRmssd: timeDomain.rmssd)

        let interpretation = HRVInterpretationEngine.interpret(HRVInterpretationEngine.Input(
            timeDomain: timeDomain,
            geometric: geometric,
            qualityScore: quality.qualityScore,
            qualityLabel: quality.qualityLabel,
            artifactPercentage: artifact.artifactPercentage,
            durationSeconds: durationSeconds,
            baseline: baseline,
            tags: tags))

        return HRVAnalysis(
            id: id,
            timestamp: timestamp,
            source: source,
            scanMode: scanMode,
            durationSeconds: durationSeconds,
            totalBeats: rawIntervalsMs.count,
            validIntervalsCount: artifact.validIntervalsCount,
            artifactCount: artifact.artifactCount,
            artifactPercentage: artifact.artifactPercentage,
            qualityScore: quality.qualityScore,
            qualityLabel: quality.qualityLabel,
            rawIntervalsMs: rawIntervalsMs,
            cleanIntervalsMs: clean,
            timeDomain: timeDomain,
            geometric: geometric,
            nonlinear: nonlinear,
            frequencyDomain: frequency,
            baseline: baseline,
            interpretation: interpretation,
            tags: tags)
    }

    // MARK: - Helpers

    private static func rejectedAnalysis(id: UUID, timestamp: Date, source: HRVSource,
                                         scanMode: HRVScanMode, durationSeconds: Double,
                                         artifact: HRVArtifactResult, quality: HRVQualityResult,
                                         tags: [HRVUserTag]) -> HRVAnalysis {
        let zeroTime = HRVTimeDomainMetrics(
            heartRateBpm: 0, meanNN: 0, medianNN: 0, minNN: 0, maxNN: 0, sdnn: 0,
            rmssd: 0, lnRmssd: 0, nn50: 0, pnn50: 0, sdsd: 0, cvnn: 0, cvsd: 0)
        let interpretation = HRVInterpretation(
            readiness: .uncertain, recoverySignal: .unknown, stressLoad: .unknown,
            autonomicBalance: .uncertain,
            summaryKey: "hrv.interpretation.uncertain.bad_quality.summary",
            recommendationKey: "hrv.interpretation.uncertain.bad_quality.recommendation",
            explanationKeys: [], confidence: .low, contributingFactors: ["rejected_scan"])
        return HRVAnalysis(
            id: id, timestamp: timestamp, source: source, scanMode: scanMode,
            durationSeconds: durationSeconds, totalBeats: artifact.rawIntervalsMs.count,
            validIntervalsCount: artifact.validIntervalsCount,
            artifactCount: artifact.artifactCount, artifactPercentage: artifact.artifactPercentage,
            qualityScore: quality.qualityScore, qualityLabel: quality.qualityLabel,
            rawIntervalsMs: artifact.rawIntervalsMs, cleanIntervalsMs: [],
            timeDomain: zeroTime,
            geometric: HRVGeometricMetrics(modeNN: nil, amo50: nil, mxdmn: nil,
                                           triangularIndex: nil, tinn: nil, histogramBins: []),
            nonlinear: HRVNonlinearMetrics(sd1: nil, sd2: nil, sd1sd2: nil, poincarePoints: [],
                                           sampleEntropy: nil, approximateEntropy: nil,
                                           dfaAlpha1: nil, dfaAlpha2: nil),
            frequencyDomain: HRVFrequencyDomainMetrics(available: false,
                                                       unavailableReason: "scan_rejected"),
            baseline: nil, interpretation: interpretation, tags: tags)
    }
}
