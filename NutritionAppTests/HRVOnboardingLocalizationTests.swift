import XCTest
@testable import NutritionApp

final class HRVOnboardingLocalizationTests: XCTestCase {

    // MARK: - Onboarding state

    private func freshDefaults() -> UserDefaults {
        let suite = "hrv.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func testOnboardingShownThenNotRepeated() {
        let state = HRVOnboardingState(defaults: freshDefaults())
        XCTAssertTrue(state.shouldShowOnboarding())
        state.markCompleted()
        XCTAssertFalse(state.shouldShowOnboarding())
    }

    func testOnboardingCanBeReopened() {
        let state = HRVOnboardingState(defaults: freshDefaults())
        state.markCompleted()
        XCTAssertFalse(state.shouldShowOnboarding())
        state.reset()
        XCTAssertTrue(state.shouldShowOnboarding())
    }

    func testPreScanChecklistShownForEarlyUsers() {
        let state = HRVOnboardingState(defaults: freshDefaults())
        XCTAssertTrue(state.showPreScanChecklist(validScanCount: 2))    // early user
        XCTAssertFalse(state.showPreScanChecklist(validScanCount: 20))  // experienced
        state.setShowPreScanChecklist(true)
        XCTAssertTrue(state.showPreScanChecklist(validScanCount: 20))   // explicit preference wins
    }

    func testAutomationFlagsDefaultOffInNormalRun() {
        // Production safety: nothing is forced unless a launch flag is set.
        XCTAssertFalse(HRVAutomation.autoCompleteOnboarding)
        XCTAssertFalse(HRVAutomation.simulateScan)
    }

    // MARK: - Localization completeness

    /// Every user-facing key produced by the HRV engines, plus onboarding and the
    /// core metric glossary, must resolve in both English and German.
    private var requiredKeys: [String] {
        var keys = HRVOnboarding.allKeys

        // Quality.
        keys += ["hrv.quality.excellent", "hrv.quality.good", "hrv.quality.usable",
                 "hrv.quality.weak", "hrv.quality.invalid",
                 "hrv.quality.message.rejected", "hrv.quality.message.high_artifacts",
                 "hrv.quality.message.moderate_artifacts", "hrv.quality.message.low_artifacts",
                 "hrv.quality.message.short_scan", "hrv.quality.message.too_short"]

        // Interpretation summaries + recommendations.
        for branch in ["uncertain.bad_quality", "baseline.none", "push", "normal",
                       "maintain", "recover", "high_hrv_fatigue", "high_hrv_good"] {
            keys.append("hrv.interpretation.\(branch).summary")
            keys.append("hrv.interpretation.\(branch).recommendation")
        }
        keys.append("hrv.explanation.amo50_elevated")

        // Reminders.
        keys += ["hrv.reminders.no_measurement.title",
                 "hrv.reminders.no_measurement.general.body",
                 "hrv.reminders.no_measurement.baseline_building.body",
                 "hrv.reminders.bad_quality.title", "hrv.reminders.bad_quality.body"]
        for r in ["push", "normal", "maintain", "recover", "uncertain"] {
            keys.append("hrv.reminders.with_measurement.\(r).title")
            keys.append("hrv.reminders.with_measurement.\(r).body")
        }

        // Scan signal feedback.
        for s in ["good", "too_much_pressure", "too_little_pressure", "finger_moved",
                  "camera_not_covered", "hold_still", "breathe_normally", "almost_done", "complete"] {
            keys.append("hrv.scan.signal.\(s)")
        }

        // Core metric glossary (the localized subset).
        for metric in ["rmssd", "sdnn", "pnn50", "amo50", "lfhf"] {
            if let def = HRVMetricDefinitions.definition(for: metric) {
                keys += [def.titleKey, def.shortDescriptionKey, def.whatItMeansKey,
                         def.whenLowKey, def.whenHighKey, def.reliabilityKey]
            }
        }
        return keys
    }

    func testAllRequiredKeysResolveInEnglish() {
        let lm = LocalizationManager.shared
        for key in requiredKeys {
            let value = lm.string(key, language: .english)
            XCTAssertNotEqual(value, key, "Missing English string for key: \(key)")
            XCTAssertFalse(value.isEmpty, "Empty English string for key: \(key)")
        }
    }

    func testAllRequiredKeysResolveInGerman() {
        let lm = LocalizationManager.shared
        for key in requiredKeys {
            let value = lm.string(key, language: .german)
            XCTAssertNotEqual(value, key, "Missing German string for key: \(key)")
            XCTAssertFalse(value.isEmpty, "Empty German string for key: \(key)")
        }
    }

    func testGermanDiffersFromEnglish() {
        let lm = LocalizationManager.shared
        XCTAssertEqual(lm.string("hrv.quality.good", language: .german), "Gut")
        XCTAssertNotEqual(lm.string("hrv.quality.good", language: .german),
                          lm.string("hrv.quality.good", language: .english))
    }

    func testMissingLocaleFallsBackToEnglish() {
        let lm = LocalizationManager.shared
        // Japanese has no .lproj yet, so it must fall back to the English string.
        let ja = lm.string("hrv.interpretation.normal.summary", language: .japanese)
        let en = lm.string("hrv.interpretation.normal.summary", language: .english)
        XCTAssertEqual(ja, en)
    }

    func testNoEnDashesInLocalizedHRVStrings() {
        let lm = LocalizationManager.shared
        let dash = CharacterSet(charactersIn: "\u{2013}\u{2014}")   // en-dash, em-dash
        for key in requiredKeys {
            for lang in [AppLanguage.english, .german] {
                let value = lm.string(key, language: lang)
                XCTAssertNil(value.rangeOfCharacter(from: dash),
                             "Dash found in \(lang) string for key: \(key)")
            }
        }
    }
}
