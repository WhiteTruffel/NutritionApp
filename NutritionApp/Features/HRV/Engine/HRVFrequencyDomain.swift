import Foundation

/// Frequency-domain HRV. This module is deliberately conservative: it implements
/// the *gating* logic that decides whether a frequency analysis is even
/// admissible, and refuses to produce any LF/HF/VLF/Total-Power numbers without a
/// real power-spectral-density implementation. Fabricated spectral values would
/// be scientifically meaningless, so we return `available = false` with a reason
/// instead.
enum HRVFrequencyDomain {

    struct GateResult: Equatable {
        var available: Bool
        var reason: String?
    }

    struct GateInput {
        var durationSeconds: Double
        var validIntervalsCount: Int
        var qualityScore: Int
        var artifactPercentage: Double
    }

    static func canCalculate(_ input: GateInput) -> GateResult {
        if input.durationSeconds < HRVConstants.frequencyMinDurationSeconds
            && input.validIntervalsCount < HRVConstants.frequencyMinCleanBeats {
            return GateResult(available: false, reason: "frequency_requires_longer_scan")
        }
        if input.qualityScore < HRVConstants.frequencyMinQualityScore {
            return GateResult(available: false, reason: "frequency_requires_better_quality")
        }
        if input.artifactPercentage > HRVConstants.frequencyMaxArtifactPercentage {
            return GateResult(available: false, reason: "frequency_too_many_artifacts")
        }
        return GateResult(available: true, reason: nil)
    }

    static func metrics(intervalsMs: [Double],
                        durationSeconds: Double,
                        qualityScore: Int,
                        artifactPercentage: Double) -> HRVFrequencyDomainMetrics {
        let gate = canCalculate(GateInput(
            durationSeconds: durationSeconds,
            validIntervalsCount: intervalsMs.count,
            qualityScore: qualityScore,
            artifactPercentage: artifactPercentage))

        guard gate.available else {
            return HRVFrequencyDomainMetrics(available: false, unavailableReason: gate.reason)
        }

        // A real Welch PSD or Lomb-Scargle periodogram belongs here. Until that
        // exists we explicitly mark the result unavailable rather than invent
        // band powers.
        return HRVFrequencyDomainMetrics(
            available: false, unavailableReason: "frequency_not_implemented_yet")
    }
}
