import Foundation

/// Stubbed interval source. The real signal-acquisition layer (AVFoundation
/// camera PPG: torch on, per-frame red-channel averaging, peak detection → RR
/// intervals) is a separate follow-up. Until then this generates physiologically
/// plausible interval streams so the whole engine, persistence, baseline, and
/// interpretation pipeline can run and be exercised end to end.
///
/// It is also handy for previews, demos, and seeding history. It is deterministic
/// when given a seed, which keeps tests reproducible.
struct HRVIntervalSimulator {

    /// A simple, seedable LCG so generated data is reproducible in tests.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    /// Generate `beatCount` intervals around a target mean heart rate, with a
    /// controllable amount of beat-to-beat variability (ms) and an optional rate
    /// of injected artifacts (0...1).
    /// - Returns: raw intervals in milliseconds.
    static func generate(beatCount: Int,
                         meanHeartRate: Double = 62,
                         sdMs: Double = 45,
                         artifactRate: Double = 0,
                         seed: UInt64 = 0x1234_5678) -> [Double] {
        guard beatCount > 0, meanHeartRate > 0 else { return [] }
        var rng = SeededGenerator(seed: seed)
        let meanIntervalMs = 60000.0 / meanHeartRate

        var intervals: [Double] = []
        intervals.reserveCapacity(beatCount)
        for _ in 0..<beatCount {
            // Approximate a normal deviate from the average of several uniforms.
            let noise = gaussian(using: &rng) * sdMs
            var value = meanIntervalMs + noise

            // Optionally inject an obvious artifact (dropped/extra beat).
            if artifactRate > 0, Double.random(in: 0...1, using: &rng) < artifactRate {
                value = Bool.random(using: &rng)
                    ? value * 0.45          // far too short
                    : value * 1.9           // far too long
            }
            intervals.append(value)
        }
        return intervals
    }

    /// Approximate standard-normal sample via the central-limit trick (sum of 6
    /// uniforms, centred and scaled). Adequate for simulated PPG variability.
    private static func gaussian(using rng: inout SeededGenerator) -> Double {
        var sum = 0.0
        for _ in 0..<6 { sum += Double.random(in: 0...1, using: &rng) }
        return (sum - 3.0) / 1.732_050_8   // mean 0, variance ~1
    }

    /// Convenience generators for the three scan depths (intervals only; the
    /// duration is derived from the mean interval).
    static func quickScan(seed: UInt64 = 0x1234_5678) -> [Double] {
        generate(beatCount: 120, meanHeartRate: 62, sdMs: 45, artifactRate: 0.01, seed: seed)
    }

    static func standardScan(seed: UInt64 = 0x1234_5678) -> [Double] {
        generate(beatCount: 320, meanHeartRate: 60, sdMs: 50, artifactRate: 0.01, seed: seed)
    }
}
