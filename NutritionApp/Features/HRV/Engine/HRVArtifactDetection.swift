import Foundation

/// Artifact detection and cleaning for raw RR/NN intervals.
///
/// Two-stage rejection:
///  1. Physiological bounds: anything outside 300-2000 ms is an artifact.
///  2. Local-median test: a beat that deviates from the median of its neighbours
///     by more than `artifactLocalMedianThreshold` is an artifact.
/// Isolated artifacts are interpolated from the nearest valid neighbours. A scan
/// with too few clean intervals or too high an artifact rate is rejected.
enum HRVArtifactDetection {

    static func isPhysiological(_ intervalMs: Double) -> Bool {
        intervalMs >= HRVConstants.minPhysiologicalIntervalMs
            && intervalMs <= HRVConstants.maxPhysiologicalIntervalMs
            && intervalMs.isFinite
    }

    static func clean(_ rawIntervalsMs: [Double]) -> HRVArtifactResult {
        guard !rawIntervalsMs.isEmpty else {
            return HRVArtifactResult(
                rawIntervalsMs: [], cleanIntervalsMs: [], artifactIndices: [],
                artifactCount: 0, artifactPercentage: 100, validIntervalsCount: 0,
                rejected: true, rejectionReason: "no_intervals")
        }

        let count = rawIntervalsMs.count
        var artifactIndices = Set<Int>()
        var cleaned = rawIntervalsMs

        // Stage 1: physiological bounds.
        for i in 0..<count where !isPhysiological(rawIntervalsMs[i]) {
            artifactIndices.insert(i)
        }

        // Stage 2: local-median deviation (skip already-flagged beats).
        let w = HRVConstants.artifactWindowHalfWidth
        for i in 0..<count {
            if artifactIndices.contains(i) { continue }
            let lo = max(0, i - w)
            let hi = min(count - 1, i + w)
            // Neighbour window excluding the beat under test, physiological only.
            var window: [Double] = []
            for j in lo...hi where j != i && isPhysiological(rawIntervalsMs[j]) {
                window.append(rawIntervalsMs[j])
            }
            guard window.count >= 3 else { continue }
            let localMed = HRVStatistics.median(window)
            guard localMed > 0 else { continue }
            let relDiff = abs(rawIntervalsMs[i] - localMed) / localMed
            if relDiff > HRVConstants.artifactLocalMedianThreshold {
                artifactIndices.insert(i)
            }
        }

        // Interpolate isolated artifacts from nearest valid neighbours.
        for index in artifactIndices {
            if let prev = previousValid(in: cleaned, before: index, artifacts: artifactIndices),
               let next = nextValid(in: cleaned, after: index, artifacts: artifactIndices) {
                cleaned[index] = (prev + next) / 2
            }
        }

        // Final clean set: keep only physiological, finite values.
        let cleanIntervalsMs = cleaned.filter { isPhysiological($0) }

        let artifactCount = artifactIndices.count
        let artifactPercentage = Double(artifactCount) / Double(count) * 100
        let validCount = cleanIntervalsMs.count
        let rejected = validCount < HRVConstants.minCleanIntervalsForValidScan
            || artifactPercentage > HRVConstants.maxArtifactPercentageForValidScan

        return HRVArtifactResult(
            rawIntervalsMs: rawIntervalsMs,
            cleanIntervalsMs: cleanIntervalsMs,
            artifactIndices: artifactIndices.sorted(),
            artifactCount: artifactCount,
            artifactPercentage: artifactPercentage,
            validIntervalsCount: validCount,
            rejected: rejected,
            rejectionReason: rejected ? "too_many_artifacts_or_too_few_intervals" : nil)
    }

    // MARK: - Neighbour lookup

    private static func previousValid(in values: [Double], before index: Int,
                                      artifacts: Set<Int>) -> Double? {
        var i = index - 1
        while i >= 0 {
            if !artifacts.contains(i) && isPhysiological(values[i]) { return values[i] }
            i -= 1
        }
        return nil
    }

    private static func nextValid(in values: [Double], after index: Int,
                                  artifacts: Set<Int>) -> Double? {
        var i = index + 1
        while i < values.count {
            if !artifacts.contains(i) && isPhysiological(values[i]) { return values[i] }
            i += 1
        }
        return nil
    }
}
