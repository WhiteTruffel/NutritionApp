# Feature: Localization + Onboarding Redesign + Hydration Rings + HRV + Reminders

**Branch:** `feature/onboarding-localization-wHydration-reminders-settings`

**Status:** FOUNDATION LAID, SKELETON EXECUTABLE

---

## What's Done (Ready to Test)

### Phase 1: Models & Settings ✅
- [x] `AppSettings.swift`: All enums (16 languages, regions, units, skin types, gender)
- [x] `RemindersSettings.swift`: Reminder configuration model
- [x] Localization strings: German + English (base set)
- [x] AppSettingsState observable for persistence

### Phase 2: Localization Infrastructure (Skeleton)
- [x] Directory structure: `Resources/Localization/de.lproj/` + `en.lproj/`
- [x] Localizable.strings files (EN + DE, core strings)
- [ ] LocalizationManager for runtime language switching (TODO)
- [ ] String() extension with language awareness (TODO)
- [ ] 14 additional languages (TODO: FR, AF, HI, FA, AR, JA, ZH, SR, HR, RU, HU, IT, ES, PT, PT-BR, KO)

### Phase 3: New Onboarding (Skeleton)
- [ ] OnboardingView redesign (non-skippable, 3-4 screens)
  - Screen 1: Region + Language selection
  - Screen 2: Format (units) + Gender + Height + Age + Skin Type
  - Screen 3: Confirmation / Ready to use
  - Screen 4: Reminders setup (optional: may fold into Screen 3)
- [ ] Form validation logic
- [ ] Test defaults (Germany/German/metric/male/180cm/30yo/SkinTypeII)
- [ ] Maestro testability (auto-fill defaults for simulator)

### Phase 4: Trinken Weekly Rings (Skeleton)
- [ ] WeeklyHydrationRingsView: Circular progress rings (Mon-Sun)
- [ ] Color coding: Red (<70%), Amber (70-89%), Green (90%+)
- [ ] Historical data: seed 12 weeks of test data
- [ ] Scrollable past/future weeks
- [ ] Region-aware quick-add buttons (ml vs fl oz)
- [ ] Integration into existing FluidsView

### Phase 5: HRV Camera Measurement (Skeleton)
- [ ] HRVMeasurementView: Camera UI for measurement
- [ ] HealthKit integration: read HRV samples
- [ ] Recovery advice logic:
  - HRV > 75th percentile: "Crush the day"
  - HRV > 50th: "Good to train"
  - HRV > 25th: "Moderate activity"
  - HRV < 25th: "Take it easy"
- [ ] Save results to HealthKit

### Phase 6: Reminders System (Skeleton)
- [ ] Morning motivation reminder (configurable time)
- [ ] Meal reminders: breakfast (9am), lunch (1pm), dinner (7pm)
- [ ] Snooze: 30min / 60min options
- [ ] Bedtime reminder (user-configured, 1hr before bedtime)
- [ ] Settings UI to enable/disable + adjust times
- [ ] UserNotifications integration

### Phase 7: Settings Redesign (Skeleton)
- [ ] SettingsView: Access to all new preferences
  - Change region/language/format
  - Edit personal data (height, age, gender, skin type)
  - Manage reminders (on/off, times, snooze)
  - Set sleep schedule (for bedtime reminder)
  - Recommend app (share via Messages/Email/AirDrop → App Store link)

### Phase 8: Test Data (Skeleton)
- [ ] Seed 12 weeks of hydration history (daily 2000-2600ml mock data)
- [ ] Vary daily intake (some days green, some amber, some red)
- [ ] Make seeding automatic on first launch if no data exists

---

## TODO (Next Priorities)

### Immediate (Critical Path)
1. **LocalizationManager.swift** - Runtime language switching with @Observable
2. **New OnboardingView (3 screens)** - Non-skippable form with validation
3. **WeeklyHydrationRingsView** - Circular SwiftUI progress (custom Shape)
4. **Persist AppSettingsState** - UserDefaults or SwiftData binding
5. **Integration into RootTabView** - Trigger onboarding if not completed

### High Priority
6. **HRVMeasurementView** - HealthKit read + recovery advice logic
7. **RemindersManager** - UserNotifications setup + schedule logic
8. **SettingsView redesign** - New UI for all preferences
9. **Maestro test defaults** - Simulator auto-fill for test automation
10. **Test data seeding** - 12 weeks of hydration history

### Medium Priority
11. **Complete localizations** - 14 additional languages (FR, AF, HI, etc.)
12. **Region → Units mapping** - Auto-suggest metric vs imperial
13. **Sleep schedule integration** - Bedtime reminder logic
14. **HRV camera capture** - Actual vision/camera implementation (not just stub)

### Polish
15. Theme/colors for rings (red/amber/green in Theme.swift)
16. Animations for ring fill
17. Week navigation (< > buttons, today highlight)
18. Recommend app deep linking

---

## Testing Strategy

**Simulator Auto-Test (No Manual Intervention):**
- Hardcoded defaults: Germany/German/metric/male/180cm/30yo/SkinTypeII
- Onboarding auto-fills and completes
- Weekly view shows 12 weeks test data
- Maestro flows: swipe week, tap reminders, check rings colors

**Manual Testing (Before Release):**
- Install on actual iPhone, test HRV camera
- Test actual push notifications (reminders)
- Check landscape/dark mode
- Test all 16 languages (at least spot-check)

---

## Files Created This Session

```
NutritionApp/Models/AppSettings.swift
NutritionApp/Resources/Localization/en.lproj/Localizable.strings
NutritionApp/Resources/Localization/de.lproj/Localizable.strings
FEATURE_BUILDOUT_STATUS.md (this file)
```

---

## Files to Create Next Session

- LocalizationManager.swift
- Views/Onboarding/OnboardingRegionScreen.swift
- Views/Onboarding/OnboardingPersonalScreen.swift
- Views/Onboarding/OnboardingConfirmationScreen.swift
- Views/Fluids/WeeklyHydrationRingsView.swift
- Views/HRV/HRVMeasurementView.swift
- Views/Reminders/RemindersSettingsView.swift
- Services/RemindersManager.swift
- Localizable.strings for 14 additional languages
- etc.

---

**Next Session:** Start with LocalizationManager + OnboardingRegionScreen. Build incrementally, test in simulator each time. Full feature complete in 2-3 more sessions.
