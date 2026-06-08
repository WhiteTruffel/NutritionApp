import Foundation

/// Deterministic, rule-based interpretation of a scan against the personal
/// baseline. No machine learning, no hidden state: given the same inputs it
/// always returns the same readiness/recovery/stress/balance verdict, which makes
/// it fully testable.
///
/// LF/HF is never used as a primary decision factor; it may only appear as
/// supporting context in `explanationKeys`.
enum HRVInterpretationEngine {

    struct Input {
        var timeDomain: HRVTimeDomainMetrics
        var geometric: HRVGeometricMetrics
        var qualityScore: Int
        var qualityLabel: HRVQualityLabel
        var artifactPercentage: Double
        var durationSeconds: Double
        var baseline: HRVBaselineSnapshot?
        var tags: [HRVUserTag]

        init(timeDomain: HRVTimeDomainMetrics,
             geometric: HRVGeometricMetrics,
             qualityScore: Int,
             qualityLabel: HRVQualityLabel,
             artifactPercentage: Double,
             durationSeconds: Double,
             baseline: HRVBaselineSnapshot? = nil,
             tags: [HRVUserTag] = []) {
            self.timeDomain = timeDomain
            self.geometric = geometric
            self.qualityScore = qualityScore
            self.qualityLabel = qualityLabel
            self.artifactPercentage = artifactPercentage
            self.durationSeconds = durationSeconds
            self.baseline = baseline
            self.tags = tags
        }
    }

    static func interpret(_ input: Input) -> HRVInterpretation {
        let hasFatigueOrIllness = input.tags.contains(.fatigue) || input.tags.contains(.illness)

        // 1. Poor quality → do not over-interpret.
        if input.qualityScore < HRVConstants.qualityUsableMin {
            return HRVInterpretation(
                readiness: .uncertain,
                recoverySignal: .unknown,
                stressLoad: .unknown,
                autonomicBalance: .uncertain,
                summaryKey: "hrv.interpretation.uncertain.bad_quality.summary",
                recommendationKey: "hrv.interpretation.uncertain.bad_quality.recommendation",
                explanationKeys: [],
                confidence: .low,
                contributingFactors: ["low_quality"])
        }

        // 2. No / insufficient baseline → conservative.
        guard let baseline = input.baseline, baseline.baselineStatus != .none,
              let baselineRmssd = HRVBaselineEngine.preferredBaseline(
                rmssd30: baseline.rmssd30d, rmssd14: baseline.rmssd14d, rmssd7: baseline.rmssd7d),
              baselineRmssd > 0 else {
            return HRVInterpretation(
                readiness: .uncertain,
                recoverySignal: .unknown,
                stressLoad: .unknown,
                autonomicBalance: .uncertain,
                summaryKey: "hrv.interpretation.baseline.none.summary",
                recommendationKey: "hrv.interpretation.baseline.none.recommendation",
                explanationKeys: [],
                confidence: .low,
                contributingFactors: ["baseline_building"])
        }

        // 3. Deviations vs baseline (RMSSD required; HR/SDNN optional).
        let currentRmssd = input.timeDomain.rmssd
        let rmssdDev = (currentRmssd - baselineRmssd) / baselineRmssd * 100

        let baselineHr = HRVBaselineEngine.preferredBaseline(
            rmssd30: baseline.hr30d, rmssd14: baseline.hr14d, rmssd7: baseline.hr7d)
        let hrDev: Double = {
            guard let bhr = baselineHr, bhr > 0 else { return 0 }
            return (input.timeDomain.heartRateBpm - bhr) / bhr * 100
        }()

        let baselineSdnn = HRVBaselineEngine.preferredBaseline(
            rmssd30: baseline.sdnn30d, rmssd14: baseline.sdnn14d, rmssd7: baseline.sdnn7d)
        let sdnnDev: Double? = {
            guard let bs = baselineSdnn, bs > 0 else { return nil }
            return (input.timeDomain.sdnn - bs) / bs * 100
        }()

        let goodQuality = input.qualityScore >= HRVConstants.qualityGoodMin
        var factors: [String] = []
        var explanations: [String] = []

        // 4. Unusually high HRV (checked before push/normal).
        if rmssdDev > HRVConstants.rmssdUnusuallyHighPercent {
            factors.append("rmssd_far_above_baseline")
            if hasFatigueOrIllness {
                factors.append(input.tags.contains(.illness) ? "illness_tag" : "fatigue_tag")
                return HRVInterpretation(
                    readiness: .maintain,
                    recoverySignal: .unusuallyHigh,
                    stressLoad: .unknown,
                    autonomicBalance: .parasympathetic,
                    summaryKey: "hrv.interpretation.high_hrv_fatigue.summary",
                    recommendationKey: "hrv.interpretation.high_hrv_fatigue.recommendation",
                    explanationKeys: explanations,
                    confidence: .medium,
                    contributingFactors: factors)
            } else {
                return HRVInterpretation(
                    readiness: goodQuality ? .push : .normal,
                    recoverySignal: .strong,
                    stressLoad: .calm,
                    autonomicBalance: .parasympathetic,
                    summaryKey: "hrv.interpretation.high_hrv_good.summary",
                    recommendationKey: "hrv.interpretation.high_hrv_good.recommendation",
                    explanationKeys: explanations,
                    confidence: goodQuality ? .high : .medium,
                    contributingFactors: factors)
            }
        }

        // Count suppressed markers for the "recover" branch.
        var suppressedMarkers = 0
        if rmssdDev <= HRVConstants.rmssdStrongDropPercent { suppressedMarkers += 1; factors.append("rmssd_low") }
        if let s = sdnnDev, s <= HRVConstants.rmssdStrongDropPercent { suppressedMarkers += 1; factors.append("sdnn_low") }
        if hrDev > HRVConstants.hrStrongRisePercent { suppressedMarkers += 1; factors.append("hr_elevated") }
        if let amo = input.geometric.amo50, amo > 50 { explanations.append("hrv.explanation.amo50_elevated") }

        // 5. Recover / overloaded.
        let strongDropWithHr = rmssdDev < HRVConstants.rmssdStrongDropPercent
            && hrDev > HRVConstants.hrStrongRisePercent
        if strongDropWithHr || suppressedMarkers >= 2 {
            let veryLow = rmssdDev <= HRVConstants.veryLowRmssdDropPercent
            return HRVInterpretation(
                readiness: .recover,
                recoverySignal: veryLow ? .veryLow : .low,
                stressLoad: (strongDropWithHr && veryLow) ? .overloaded : .strained,
                autonomicBalance: .sympathetic,
                summaryKey: "hrv.interpretation.recover.summary",
                recommendationKey: "hrv.interpretation.recover.recommendation",
                explanationKeys: explanations,
                confidence: goodQuality ? .high : .medium,
                contributingFactors: factors)
        }

        // 6. Maintain / mildly activated.
        let mildDrop = rmssdDev < HRVConstants.rmssdMildDropPercent
            && rmssdDev >= HRVConstants.rmssdStrongDropPercent
        let mildHrRise = hrDev > HRVConstants.hrMildRisePercent
            && hrDev <= HRVConstants.hrStrongRisePercent
        if mildDrop || mildHrRise {
            if mildDrop { factors.append("rmssd_mildly_below_baseline") }
            if mildHrRise { factors.append("hr_mildly_elevated") }
            return HRVInterpretation(
                readiness: .maintain,
                recoverySignal: .low,
                stressLoad: .activated,
                autonomicBalance: .mixed,
                summaryKey: "hrv.interpretation.maintain.summary",
                recommendationKey: "hrv.interpretation.maintain.recommendation",
                explanationKeys: explanations,
                confidence: .medium,
                contributingFactors: factors)
        }

        // 7. Push (recovered) — clearly above baseline, HR not elevated, feeling fine.
        if rmssdDev >= HRVConstants.rmssdElevatedPercent
            && hrDev <= HRVConstants.hrMildRisePercent
            && !hasFatigueOrIllness && goodQuality {
            factors.append("rmssd_above_baseline")
            return HRVInterpretation(
                readiness: .push,
                recoverySignal: .strong,
                stressLoad: .calm,
                autonomicBalance: .parasympathetic,
                summaryKey: "hrv.interpretation.push.summary",
                recommendationKey: "hrv.interpretation.push.recommendation",
                explanationKeys: explanations,
                confidence: .high,
                contributingFactors: factors)
        }

        // 8. Normal / balanced (default).
        factors.append("within_normal_range")
        return HRVInterpretation(
            readiness: .normal,
            recoverySignal: .normal,
            stressLoad: .balanced,
            autonomicBalance: .balanced,
            summaryKey: "hrv.interpretation.normal.summary",
            recommendationKey: "hrv.interpretation.normal.recommendation",
            explanationKeys: explanations,
            confidence: goodQuality ? .high : .medium,
            contributingFactors: factors)
    }
}
