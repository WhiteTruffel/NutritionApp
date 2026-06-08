import Foundation

/// Tracks whether the user has completed (or skipped) HRV onboarding, plus the
/// pre-scan checklist preference. Backed by `UserDefaults`, but the store is
/// injectable so the logic is unit-testable without touching the standard suite.
struct HRVOnboardingState {
    private let defaults: UserDefaults
    private let completedKey = "hrv.onboarding.completed"
    private let showChecklistKey = "hrv.settings.showPreScanChecklist"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True once onboarding has been completed or explicitly skipped. Automation
    /// (UI/integration tests) can force this on via a launch flag so the
    /// non-skippable flow does not block autonomous runs.
    var isCompleted: Bool {
        get { HRVAutomation.autoCompleteOnboarding || defaults.bool(forKey: completedKey) }
        nonmutating set { defaults.set(newValue, forKey: completedKey) }
    }

    func markCompleted() { isCompleted = true }

    /// Reset so onboarding can be reopened from settings.
    func reset() { defaults.set(false, forKey: completedKey) }

    /// Whether to show the measurement tips/checklist before a scan.
    /// Defaults to true, and is forced on for early users (no value stored yet).
    func showPreScanChecklist(validScanCount: Int) -> Bool {
        if defaults.object(forKey: showChecklistKey) == nil {
            // Always show the checklist while the user is still inexperienced.
            return validScanCount < HRVConstants.baselineMinScansEarly
        }
        return defaults.bool(forKey: showChecklistKey)
    }

    func setShowPreScanChecklist(_ value: Bool) {
        defaults.set(value, forKey: showChecklistKey)
    }

    /// Whether onboarding should be shown for this entry into the HRV feature.
    func shouldShowOnboarding() -> Bool { !isCompleted }
}
