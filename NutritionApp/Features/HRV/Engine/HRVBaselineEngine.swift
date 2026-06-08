import Foundation

/// Personal-baseline engine. Builds rolling 7/14/30-day context from historical
/// valid scans. Baseline values use the **median** (robust to the odd bad day),
/// plus a robust median/MAD/z-score for RMSSD specifically.
///
/// Time-of-day fairness: when a preferred bucket is supplied and there are enough
/// same-bucket samples, the baseline is computed from those only, so a morning
/// reading is compared to morning history rather than to evening readings.
enum HRVBaselineEngine {

    /// Minimum same-time-of-day samples within a window before we trust a
    /// time-of-day-restricted baseline over the unrestricted one.
    static let minSameTimeOfDaySamples = 3

    static func status(validScanCount: Int) -> HRVBaselineStatus {
        if validScanCount < HRVConstants.baselineMinScansBuilding { return .none }
        if validScanCount < HRVConstants.baselineMinScansEarly { return .building }
        if validScanCount < HRVConstants.baselineMinScansMedium { return .early }
        if validScanCount < HRVConstants.baselineMinScansReady { return .medium }
        return .ready
    }

    /// Builds a baseline snapshot from history.
    /// - Parameters:
    ///   - samples: historical valid scans (current scan excluded).
    ///   - now: reference time for the rolling windows.
    ///   - preferredTimeOfDay: when set, prefer same-bucket history if plentiful.
    ///   - currentRmssd: if set, fills the robust z-score of the current value.
    static func snapshot(samples: [HRVBaselineSample],
                         now: Date = .now,
                         preferredTimeOfDay: HRVTimeOfDay? = nil,
                         currentRmssd: Double? = nil) -> HRVBaselineSnapshot {
        let validScanCount = samples.count
        var snap = HRVBaselineSnapshot(
            validScanCount: validScanCount,
            baselineStatus: status(validScanCount: validScanCount))

        let calendar = Calendar.current

        func windowSamples(days: Int) -> [HRVBaselineSample] {
            guard let cutoff = calendar.date(byAdding: .day, value: -days, to: now) else { return [] }
            let inWindow = samples.filter { $0.timestamp >= cutoff && $0.timestamp <= now }
            if let tod = preferredTimeOfDay {
                let sameTod = inWindow.filter { $0.timeOfDay == tod }
                if sameTod.count >= minSameTimeOfDaySamples { return sameTod }
            }
            return inWindow
        }

        func medianOrNil(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : HRVStatistics.median(values)
        }

        for days in [7, 14, 30] {
            let window = windowSamples(days: days)
            let rmssd = medianOrNil(window.map { $0.rmssd })
            let lnRmssd = medianOrNil(window.map { $0.lnRmssd })
            let hr = medianOrNil(window.map { $0.heartRateBpm })
            let sdnn = medianOrNil(window.map { $0.sdnn })
            switch days {
            case 7:
                snap.rmssd7d = rmssd; snap.lnRmssd7d = lnRmssd; snap.hr7d = hr; snap.sdnn7d = sdnn
            case 14:
                snap.rmssd14d = rmssd; snap.lnRmssd14d = lnRmssd; snap.hr14d = hr; snap.sdnn14d = sdnn
            default:
                snap.rmssd30d = rmssd; snap.lnRmssd30d = lnRmssd; snap.hr30d = hr; snap.sdnn30d = sdnn
            }
        }

        // Robust RMSSD statistics over the 30-day window.
        let window30 = windowSamples(days: 30).map { $0.rmssd }
        if !window30.isEmpty {
            let med = HRVStatistics.median(window30)
            let mad = HRVStatistics.medianAbsoluteDeviation(window30)
            snap.robustRmssdMedian30d = med
            snap.robustRmssdMad30d = mad
            if let current = currentRmssd, mad > 0 {
                // 1.4826 scales MAD to a standard-deviation-equivalent for normal data.
                snap.robustRmssdZScore = (current - med) / (1.4826 * mad)
            }
        }

        return snap
    }

    /// Returns the best available baseline value across 30 → 14 → 7-day windows.
    static func preferredBaseline(rmssd30: Double?, rmssd14: Double?, rmssd7: Double?) -> Double? {
        rmssd30 ?? rmssd14 ?? rmssd7
    }
}
