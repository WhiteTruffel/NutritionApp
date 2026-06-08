import Foundation

/// One educational onboarding step. Pure data: all user-facing text is referenced
/// by localisation key, never hard-coded, so it works across every language.
struct HRVOnboardingStep: Identifiable, Sendable, Equatable {
    var id: String
    var titleKey: String
    var bodyKey: String
    var bulletKeys: [String]
    var imageKey: String?
    var primaryCtaKey: String?
    var secondaryCtaKey: String?

    init(id: String, titleKey: String, bodyKey: String, bulletKeys: [String] = [],
         imageKey: String? = nil, primaryCtaKey: String? = nil, secondaryCtaKey: String? = nil) {
        self.id = id
        self.titleKey = titleKey
        self.bodyKey = bodyKey
        self.bulletKeys = bulletKeys
        self.imageKey = imageKey
        self.primaryCtaKey = primaryCtaKey
        self.secondaryCtaKey = secondaryCtaKey
    }
}

enum HRVOnboarding {
    /// The full onboarding sequence: what HRV is, how the camera scan works, best
    /// time, preparation, finger placement, during the scan, scan length,
    /// reading results, daily guidance, limitations, and a first-scan CTA.
    static let steps: [HRVOnboardingStep] = [
        HRVOnboardingStep(
            id: "what_is_hrv",
            titleKey: "hrv.onboarding.what_is_hrv.title",
            bodyKey: "hrv.onboarding.what_is_hrv.body",
            bulletKeys: ["hrv.onboarding.what_is_hrv.bullet_1",
                         "hrv.onboarding.what_is_hrv.bullet_2",
                         "hrv.onboarding.what_is_hrv.bullet_3"]),
        HRVOnboardingStep(
            id: "camera_scan",
            titleKey: "hrv.onboarding.camera_scan.title",
            bodyKey: "hrv.onboarding.camera_scan.body",
            bulletKeys: ["hrv.onboarding.camera_scan.bullet_1",
                         "hrv.onboarding.camera_scan.bullet_2",
                         "hrv.onboarding.camera_scan.bullet_3"]),
        HRVOnboardingStep(
            id: "best_time",
            titleKey: "hrv.onboarding.best_time.title",
            bodyKey: "hrv.onboarding.best_time.body",
            bulletKeys: ["hrv.onboarding.best_time.bullet_1",
                         "hrv.onboarding.best_time.bullet_2",
                         "hrv.onboarding.best_time.bullet_3",
                         "hrv.onboarding.best_time.bullet_4"]),
        HRVOnboardingStep(
            id: "preparation",
            titleKey: "hrv.onboarding.preparation.title",
            bodyKey: "hrv.onboarding.preparation.body",
            bulletKeys: ["hrv.onboarding.preparation.bullet_1",
                         "hrv.onboarding.preparation.bullet_2",
                         "hrv.onboarding.preparation.bullet_3",
                         "hrv.onboarding.preparation.bullet_4"]),
        HRVOnboardingStep(
            id: "finger_placement",
            titleKey: "hrv.onboarding.finger_placement.title",
            bodyKey: "hrv.onboarding.finger_placement.body",
            bulletKeys: ["hrv.onboarding.finger_placement.bullet_1",
                         "hrv.onboarding.finger_placement.bullet_2",
                         "hrv.onboarding.finger_placement.bullet_3"]),
        HRVOnboardingStep(
            id: "during_scan",
            titleKey: "hrv.onboarding.during_scan.title",
            bodyKey: "hrv.onboarding.during_scan.body",
            bulletKeys: ["hrv.onboarding.during_scan.bullet_1",
                         "hrv.onboarding.during_scan.bullet_2",
                         "hrv.onboarding.during_scan.bullet_3"]),
        HRVOnboardingStep(
            id: "scan_length",
            titleKey: "hrv.onboarding.scan_length.title",
            bodyKey: "hrv.onboarding.scan_length.body",
            bulletKeys: ["hrv.onboarding.scan_length.bullet_1",
                         "hrv.onboarding.scan_length.bullet_2",
                         "hrv.onboarding.scan_length.bullet_3"]),
        HRVOnboardingStep(
            id: "understanding_results",
            titleKey: "hrv.onboarding.results.title",
            bodyKey: "hrv.onboarding.results.body",
            bulletKeys: ["hrv.onboarding.results.bullet_1",
                         "hrv.onboarding.results.bullet_2",
                         "hrv.onboarding.results.bullet_3"]),
        HRVOnboardingStep(
            id: "daily_guidance",
            titleKey: "hrv.onboarding.daily_guidance.title",
            bodyKey: "hrv.onboarding.daily_guidance.body",
            bulletKeys: ["hrv.onboarding.daily_guidance.bullet_1",
                         "hrv.onboarding.daily_guidance.bullet_2",
                         "hrv.onboarding.daily_guidance.bullet_3"]),
        HRVOnboardingStep(
            id: "limitations",
            titleKey: "hrv.onboarding.limitations.title",
            bodyKey: "hrv.onboarding.limitations.body",
            bulletKeys: ["hrv.onboarding.limitations.bullet_1",
                         "hrv.onboarding.limitations.bullet_2",
                         "hrv.onboarding.limitations.bullet_3"]),
        HRVOnboardingStep(
            id: "first_scan",
            titleKey: "hrv.onboarding.first_scan.title",
            bodyKey: "hrv.onboarding.first_scan.body",
            primaryCtaKey: "hrv.onboarding.first_scan.primary_cta",
            secondaryCtaKey: "hrv.onboarding.first_scan.secondary_cta")
    ]

    /// Every localisation key referenced by the onboarding flow (for completeness tests).
    static var allKeys: [String] {
        steps.flatMap { step -> [String] in
            var keys = [step.titleKey, step.bodyKey] + step.bulletKeys
            if let k = step.primaryCtaKey { keys.append(k) }
            if let k = step.secondaryCtaKey { keys.append(k) }
            return keys
        }
    }
}
