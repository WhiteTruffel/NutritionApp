import Foundation

/// Time-domain HRV metrics, computed from clean NN intervals (ms).
/// All functions are pure and side-effect free.
enum HRVTimeDomain {

    static func rmssd(_ intervalsMs: [Double]) -> Double {
        let diffs = HRVStatistics.successiveDifferences(intervalsMs)
        guard !diffs.isEmpty else { return 0 }
        let squared = diffs.map { $0 * $0 }
        return HRVStatistics.mean(squared).squareRoot()
    }

    static func nn50(_ intervalsMs: [Double]) -> Int {
        let diffs = HRVStatistics.successiveDifferences(intervalsMs)
        return diffs.filter { abs($0) > 50 }.count
    }

    static func pnn50(_ intervalsMs: [Double]) -> Double {
        let diffs = HRVStatistics.successiveDifferences(intervalsMs)
        guard !diffs.isEmpty else { return 0 }
        return Double(nn50(intervalsMs)) / Double(diffs.count) * 100
    }

    static func sdsd(_ intervalsMs: [Double]) -> Double {
        let diffs = HRVStatistics.successiveDifferences(intervalsMs)
        guard diffs.count > 1 else { return 0 }
        return HRVStatistics.standardDeviation(diffs)
    }

    /// Computes the full time-domain metric set. The caller must pass a non-empty
    /// array of clean intervals; an empty array is treated as a programming error.
    static func metrics(_ intervalsMs: [Double]) -> HRVTimeDomainMetrics {
        precondition(!intervalsMs.isEmpty, "Cannot calculate HRV metrics without intervals.")

        let meanNN = HRVStatistics.mean(intervalsMs)
        let medianNN = HRVStatistics.median(intervalsMs)
        let minNN = intervalsMs.min() ?? 0
        let maxNN = intervalsMs.max() ?? 0
        let sdnn = HRVStatistics.standardDeviation(intervalsMs)
        let rmssdValue = rmssd(intervalsMs)
        let lnRmssd = rmssdValue > 0 ? log(rmssdValue) : 0
        let nn50Value = nn50(intervalsMs)
        let pnn50Value = pnn50(intervalsMs)
        let sdsdValue = sdsd(intervalsMs)
        let cvnn = meanNN > 0 ? (sdnn / meanNN) * 100 : 0
        let cvsd = meanNN > 0 ? (rmssdValue / meanNN) * 100 : 0
        let heartRateBpm = meanNN > 0 ? 60000 / meanNN : 0

        return HRVTimeDomainMetrics(
            heartRateBpm: heartRateBpm,
            meanNN: meanNN,
            medianNN: medianNN,
            minNN: minNN,
            maxNN: maxNN,
            sdnn: sdnn,
            rmssd: rmssdValue,
            lnRmssd: lnRmssd,
            nn50: nn50Value,
            pnn50: pnn50Value,
            sdsd: sdsdValue,
            cvnn: cvnn,
            cvsd: cvsd)
    }
}
