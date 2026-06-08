import Foundation

/// Pure signal processing that turns a fingertip brightness waveform (the red
/// channel averaged per camera frame) into RR/NN intervals in milliseconds.
///
/// This is the testable heart of the camera PPG pipeline. The AVFoundation
/// capture lives in `HRVCameraPPGProvider`; everything here is pure and is
/// covered by unit tests with synthetic waveforms, since a real camera cannot
/// run in the simulator.
///
/// Pipeline: light smoothing, baseline removal (detrend), adaptive-threshold
/// peak detection with a physiological refractory period, then peak-to-peak
/// timing from the real frame timestamps.
enum HRVPPGSignalProcessor {

    /// Centered moving average. `window` is the full width in samples.
    static func centeredMovingAverage(_ x: [Double], window: Int) -> [Double] {
        guard window > 1, !x.isEmpty else { return x }
        let h = window / 2
        var out = [Double](repeating: 0, count: x.count)
        for i in 0..<x.count {
            let lo = max(0, i - h)
            let hi = min(x.count - 1, i + h)
            var sum = 0.0
            for j in lo...hi { sum += x[j] }
            out[i] = sum / Double(hi - lo + 1)
        }
        return out
    }

    /// Local maxima above `threshold`, enforcing a minimum spacing (refractory).
    /// When two candidates fall within `minDistance`, the larger one wins.
    static func detectPeaks(_ x: [Double], threshold: Double, minDistance: Int) -> [Int] {
        var peaks: [Int] = []
        guard x.count >= 3 else { return peaks }
        for i in 1..<(x.count - 1) {
            guard x[i] > threshold, x[i] >= x[i - 1], x[i] > x[i + 1] else { continue }
            if let last = peaks.last, i - last < max(1, minDistance) {
                if x[i] > x[last] { peaks[peaks.count - 1] = i }
            } else {
                peaks.append(i)
            }
        }
        return peaks
    }

    /// Convert a brightness waveform and matching frame timestamps (seconds) into
    /// RR intervals (ms). Returns an empty array if the signal is too short or has
    /// no detectable pulse.
    static func intervalsMs(brightness: [Double], timestamps: [Double]) -> [Double] {
        let n = min(brightness.count, timestamps.count)
        guard n >= 10 else { return [] }
        let b = Array(brightness.prefix(n))
        let t = Array(timestamps.prefix(n))

        // Estimate sampling rate from the median frame interval.
        var dts: [Double] = []
        for i in 1..<n {
            let d = t[i] - t[i - 1]
            if d > 0 { dts.append(d) }
        }
        guard !dts.isEmpty else { return [] }
        let medianDt = HRVStatistics.median(dts)
        guard medianDt > 0 else { return [] }
        let fs = 1.0 / medianDt

        // Smooth lightly, then remove the slow baseline (DC offset + drift).
        let smoothWindow = max(1, Int((fs / 10).rounded()))
        let baselineWindow = max(3, Int(fs.rounded()))
        let smoothed = centeredMovingAverage(b, window: smoothWindow)
        let baseline = centeredMovingAverage(b, window: baselineWindow)
        var detrended = [Double](repeating: 0, count: n)
        for i in 0..<n { detrended[i] = smoothed[i] - baseline[i] }

        // Adaptive threshold and a 300 ms refractory (max ~200 bpm).
        let std = HRVStatistics.standardDeviation(detrended)
        guard std > 0 else { return [] }
        let threshold = 0.3 * std
        let minDistance = max(1, Int((0.3 * fs).rounded()))

        let peaks = detectPeaks(detrended, threshold: threshold, minDistance: minDistance)
        guard peaks.count >= 2 else { return [] }

        var intervals: [Double] = []
        intervals.reserveCapacity(peaks.count - 1)
        for k in 1..<peaks.count {
            intervals.append((t[peaks[k]] - t[peaks[k - 1]]) * 1000.0)
        }
        return intervals
    }
}
