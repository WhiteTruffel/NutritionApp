import Foundation

/// Nonlinear HRV metrics. The basic Poincaré descriptors (SD1, SD2, SD1/SD2) are
/// implemented from the standard closed-form relations to SDNN and RMSSD.
/// Sample/approximate entropy and DFA are intentionally left `nil`: they need a
/// dedicated, well-tested implementation and we do not block the first version
/// or fabricate values for them.
enum HRVNonlinear {

    static func poincarePoints(_ intervalsMs: [Double]) -> [HRVPoincarePoint] {
        guard intervalsMs.count > 1 else { return [] }
        var points: [HRVPoincarePoint] = []
        points.reserveCapacity(intervalsMs.count - 1)
        for i in 0..<(intervalsMs.count - 1) {
            points.append(HRVPoincarePoint(x: intervalsMs[i], y: intervalsMs[i + 1]))
        }
        return points
    }

    /// SD1 = RMSSD / sqrt(2) (width of the Poincaré cloud; short-term variability).
    static func sd1(rmssd: Double) -> Double {
        rmssd / 2.0.squareRoot()
    }

    /// SD2 = sqrt(2*SDNN^2 - 0.5*RMSSD^2) (length of the cloud; long-term
    /// variability). Returns `nil` if the radicand is negative (degenerate input).
    static func sd2(sdnn: Double, rmssd: Double) -> Double? {
        let value = 2 * sdnn * sdnn - 0.5 * rmssd * rmssd
        guard value >= 0 else { return nil }
        return value.squareRoot()
    }

    static func metrics(_ intervalsMs: [Double], sdnn: Double, rmssd: Double) -> HRVNonlinearMetrics {
        let sd1Value = sd1(rmssd: rmssd)
        let sd2Value = sd2(sdnn: sdnn, rmssd: rmssd)
        let ratio: Double?
        if let sd2Value, sd2Value > 0 {
            ratio = sd1Value / sd2Value
        } else {
            ratio = nil
        }
        return HRVNonlinearMetrics(
            sd1: sd1Value,
            sd2: sd2Value,
            sd1sd2: ratio,
            poincarePoints: poincarePoints(intervalsMs),
            sampleEntropy: nil,
            approximateEntropy: nil,
            dfaAlpha1: nil,
            dfaAlpha2: nil)
    }
}
