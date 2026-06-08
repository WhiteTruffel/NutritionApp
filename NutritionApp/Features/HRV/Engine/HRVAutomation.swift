import Foundation

/// Central switchboard for fully autonomous testing. Reads launch arguments and
/// environment variables so UI/integration tests (and the `test_automation.sh`
/// harness) can:
///   - skip the non-skippable onboarding, and
///   - run an HRV "camera" scan without a real device or fingertip, by feeding
///     the engine simulated intervals.
///
/// Nothing here changes production behaviour unless a flag is explicitly set.
enum HRVAutomation {

    private static var args: [String] { ProcessInfo.processInfo.arguments }
    private static var env: [String: String] { ProcessInfo.processInfo.environment }

    /// Auto-complete HRV (and general) onboarding so tests land straight in the app.
    /// Enable with launch arg `-HRVAutoCompleteOnboarding` or env `HRV_AUTO_ONBOARDING=1`.
    static var autoCompleteOnboarding: Bool {
        args.contains("-HRVAutoCompleteOnboarding") || env["HRV_AUTO_ONBOARDING"] == "1"
    }

    /// Use the simulated interval source instead of the real camera PPG capture.
    /// Enable with launch arg `-HRVSimulateScan` or env `HRV_SIMULATE_SCAN=1`.
    static var simulateScan: Bool {
        args.contains("-HRVSimulateScan") || env["HRV_SIMULATE_SCAN"] == "1"
    }

    /// Deterministic seed for the simulated scan (so a UI test gets a stable result).
    /// Set env `HRV_SIMULATE_SEED=<number>`; defaults to a fixed seed.
    static var simulatedSeed: UInt64 {
        if let raw = env["HRV_SIMULATE_SEED"], let v = UInt64(raw) { return v }
        return 0x1234_5678
    }

    /// Optional scan-quality target for the simulated scan: "clean" (default) or
    /// "noisy" to exercise the artifact/quality/uncertain paths. Env `HRV_SIMULATE_PROFILE`.
    static var simulatedProfile: String {
        env["HRV_SIMULATE_PROFILE"] ?? "clean"
    }
}
