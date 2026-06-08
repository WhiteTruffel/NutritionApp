import Foundation

/// Scan-quality scoring. Produces a 0-100 score, a coarse label, and a list of
/// localisation keys explaining any deductions. Quality gates how confidently the
/// interpretation engine will speak.
enum HRVQualityScoring {

    struct Input {
        var artifactPercentage: Double
        var validIntervalsCount: Int
        var durationSeconds: Double
        var rejected: Bool
        /// Optional upstream signal-quality (e.g. from a PPG capture); caps the score.
        var signalQualityScore: Int?

        init(artifactPercentage: Double,
             validIntervalsCount: Int,
             durationSeconds: Double,
             rejected: Bool,
             signalQualityScore: Int? = nil) {
            self.artifactPercentage = artifactPercentage
            self.validIntervalsCount = validIntervalsCount
            self.durationSeconds = durationSeconds
            self.rejected = rejected
            self.signalQualityScore = signalQualityScore
        }
    }

    static func label(for score: Int) -> HRVQualityLabel {
        if score >= HRVConstants.qualityExcellentMin { return .excellent }
        if score >= HRVConstants.qualityGoodMin { return .good }
        if score >= HRVConstants.qualityUsableMin { return .usable }
        if score >= HRVConstants.qualityWeakMin { return .weak }
        return .invalid
    }

    static func score(_ input: Input) -> HRVQualityResult {
        if input.rejected {
            return HRVQualityResult(
                qualityScore: 30, qualityLabel: .invalid,
                messages: ["hrv.quality.message.rejected"])
        }

        var score = 100
        var messages: [String] = []

        if input.artifactPercentage > 10 {
            score -= 35
            messages.append("hrv.quality.message.high_artifacts")
        } else if input.artifactPercentage > 5 {
            score -= 20
            messages.append("hrv.quality.message.moderate_artifacts")
        } else if input.artifactPercentage > 2 {
            score -= 10
            messages.append("hrv.quality.message.low_artifacts")
        }

        if input.validIntervalsCount < 60 {
            score -= 20
            messages.append("hrv.quality.message.short_scan")
        }

        if input.durationSeconds < 60 {
            score -= 20
            messages.append("hrv.quality.message.too_short")
        }

        if let signal = input.signalQualityScore {
            score = min(score, signal)
        }

        score = max(0, min(100, score))

        return HRVQualityResult(
            qualityScore: score, qualityLabel: label(for: score), messages: messages)
    }
}
