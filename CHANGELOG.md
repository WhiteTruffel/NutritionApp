# Changelog

All notable changes to NutritionApp are documented here. Each build maps to fixes, features, and issues closed.

## Build 29 (2026-06-07)

**Fixed:**
- Crash on caffeine entry delete in FluidsView (Issue #5, PR #7)
- One-way Health sync: deleting entries in app now also removes from Apple Health (Issue #2, PR #8)
- Unit test failure: SwiftData model container config (Issue #1)

**Added:**
- Körper Batterie feature

**Test Status:**
- Suite: 22/22 flows green in 19 minutes

## Build 28 (2026-06-06)

**Fixed:**
- Health Service updates (2 commits from Tobias: "diverse fixes schritte aus apple health", "health fix")

**Test Status:**
- Suite: 21/21 flows green in 16m25s (before Issue #2 merge)

## Build 18 (2026-05-xx)

**Status:**
- Baseline TestFlight build before automation began
- Contained original History crash on caffeine delete (fixed in Build 29)

---

## How to Update This File

Before each TestFlight build upload:

1. Note the Build number (Xcode: target settings, Build field)
2. List what was fixed: reference GitHub Issue numbers
3. List what was added
4. Run test suite and note result (N/N flows green in X minutes)
5. Update this file with the new Build section at the top
6. Commit: `git commit -am "CHANGELOG: Build XX"`
7. Then upload to TestFlight

Example commit message:
```
git commit -am "CHANGELOG: Build 30 – fix Issue #9, add Feature X"
```

---

## Why This Matters

- **History is searchable.** "What fixed the caffeine crash?" → CHANGELOG says Build 29.
- **Release notes are automatic.** Take Build 30 entry, paste into TestFlight Release Notes, done.
- **No guessing.** Each build has a record of what changed, not "I think Build 25 had that fix."
