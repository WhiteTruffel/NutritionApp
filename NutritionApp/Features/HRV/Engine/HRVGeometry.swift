import Foundation

/// Geometric HRV metrics (histogram, mode, AMo50, MxDMn, triangular index).
/// TINN is intentionally left as `nil`: a faithful triangular interpolation needs
/// more care than is warranted here, and we do not fake precision.
enum HRVGeometry {

    static func histogramBins(_ intervalsMs: [Double],
                              binSizeMs: Double = HRVConstants.histogramBinSizeMs) -> [HRVHistogramBin] {
        guard !intervalsMs.isEmpty, binSizeMs > 0 else { return [] }
        let minV = intervalsMs.min() ?? 0
        let maxV = intervalsMs.max() ?? 0

        // Floor min and ceil max to bin boundaries.
        let start = (minV / binSizeMs).rounded(.down) * binSizeMs
        var end = (maxV / binSizeMs).rounded(.up) * binSizeMs
        if end <= start { end = start + binSizeMs }   // guarantee at least one bin

        let binCount = max(1, Int(((end - start) / binSizeMs).rounded(.up)))
        let total = Double(intervalsMs.count)

        var bins: [HRVHistogramBin] = []
        bins.reserveCapacity(binCount)
        for i in 0..<binCount {
            let binStart = start + Double(i) * binSizeMs
            let binEnd = binStart + binSizeMs
            // Last bin is inclusive of its upper edge so the max value lands somewhere.
            let isLast = (i == binCount - 1)
            let count = intervalsMs.filter {
                $0 >= binStart && (isLast ? $0 <= binEnd : $0 < binEnd)
            }.count
            bins.append(HRVHistogramBin(
                startMs: binStart,
                endMs: binEnd,
                count: count,
                percentage: total > 0 ? Double(count) / total * 100 : 0))
        }
        return bins
    }

    /// Centre of the modal (most populated) bin.
    static func modeNN(fromBins bins: [HRVHistogramBin]) -> Double? {
        guard let modal = bins.max(by: { $0.count < $1.count }), modal.count > 0 else { return nil }
        return (modal.startMs + modal.endMs) / 2
    }

    /// Amplitude of the mode: percentage of intervals in the modal bin.
    static func amo50(_ intervalsMs: [Double], bins: [HRVHistogramBin]) -> Double? {
        guard !intervalsMs.isEmpty else { return nil }
        guard let modal = bins.max(by: { $0.count < $1.count }), modal.count > 0 else { return nil }
        return Double(modal.count) / Double(intervalsMs.count) * 100
    }

    static func mxDMn(_ intervalsMs: [Double]) -> Double? {
        guard let maxV = intervalsMs.max(), let minV = intervalsMs.min() else { return nil }
        return maxV - minV
    }

    static func triangularIndex(_ intervalsMs: [Double], bins: [HRVHistogramBin]) -> Double? {
        guard intervalsMs.count >= HRVConstants.triangularIndexMinBeats else { return nil }
        let maxBinCount = bins.map { $0.count }.max() ?? 0
        guard maxBinCount > 0 else { return nil }
        return Double(intervalsMs.count) / Double(maxBinCount)
    }

    static func metrics(_ intervalsMs: [Double]) -> HRVGeometricMetrics {
        let bins = histogramBins(intervalsMs)
        return HRVGeometricMetrics(
            modeNN: modeNN(fromBins: bins),
            amo50: amo50(intervalsMs, bins: bins),
            mxdmn: mxDMn(intervalsMs),
            triangularIndex: triangularIndex(intervalsMs, bins: bins),
            tinn: nil,
            histogramBins: bins)
    }
}
