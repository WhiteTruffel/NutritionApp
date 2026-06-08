import Foundation

/// Small, pure statistics helpers shared by the HRV metric engines.
///
/// Standard-deviation convention: we use the **sample** standard deviation
/// (divisor n-1), which is the usual choice for SDNN/SDSD in HRV analysis. This
/// is applied consistently everywhere and is covered by tests.
enum HRVStatistics {

    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let n = sorted.count
        if n % 2 == 1 {
            return sorted[n / 2]
        } else {
            return (sorted[n / 2 - 1] + sorted[n / 2]) / 2
        }
    }

    /// Sample standard deviation (n-1). Returns 0 for fewer than two values.
    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        let sumSq = values.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (sumSq / Double(values.count - 1)).squareRoot()
    }

    /// Median absolute deviation (about the median), the robust spread measure
    /// used for the RMSSD baseline z-score.
    static func medianAbsoluteDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let med = median(values)
        let deviations = values.map { abs($0 - med) }
        return median(deviations)
    }

    /// Successive differences between adjacent intervals (d[i] = x[i+1] - x[i]).
    static func successiveDifferences(_ values: [Double]) -> [Double] {
        guard values.count > 1 else { return [] }
        return zip(values.dropFirst(), values).map { $0 - $1 }
    }
}
