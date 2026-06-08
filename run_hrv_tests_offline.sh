#!/bin/bash
#
# Offline test runner for NutritionApp (works on a plane, no internet).
#
# Simulator builds need no code signing and no network. This script auto-detects
# an installed iPhone simulator, disables all package resolution, and runs the
# full XCTest suite (including the new HRV tests). Results stream to the screen
# and are saved to a log plus a .xcresult bundle you can open in Xcode.
#
# Usage:  bash run_hrv_tests_offline.sh
#
set -o pipefail
cd "$(dirname "$0")" || exit 1

SCHEME="NutritionApp"
STAMP="$(date +%Y_%m_%d_%H_%M)"
LOG="/tmp/nutrition_hrv_test_${STAMP}.log"
RESULT_BUNDLE="/tmp/nutrition_hrv_${STAMP}.xcresult"

echo "Locating an installed iOS simulator..."
# First available iPhone simulator UDID (already-installed runtime, no download).
UDID="$(xcrun simctl list devices available \
        | grep -E "iPhone" \
        | grep -oE "[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}" \
        | head -1)"

if [ -z "$UDID" ]; then
  echo "No installed iPhone simulator was found."
  echo "Open Xcode > Settings > Components and make sure an iOS Simulator runtime is installed,"
  echo "then run this script again. (That download needs internet, so do it before the flight.)"
  exit 1
fi

echo "Using simulator UDID: $UDID"
echo "Log:    $LOG"
echo "Result: $RESULT_BUNDLE"
echo "Running tests offline (this can take a few minutes on the first build)..."
echo

xcodebuild test \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -derivedDataPath ./DerivedData \
  -resultBundlePath "$RESULT_BUNDLE" \
  -disableAutomaticPackageResolution \
  -skipPackagePluginValidation \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$LOG"

STATUS=${PIPESTATUS[0]}
echo
if [ "$STATUS" -eq 0 ]; then
  echo "RESULT: all tests passed."
else
  echo "RESULT: build or tests failed (exit $STATUS)."
  echo "Failures and compile errors in: $LOG"
  echo "Quick filter:  grep -nE 'error:|failed|Failing tests' \"$LOG\""
fi
exit "$STATUS"
