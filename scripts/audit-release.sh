#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVED_DATA_PATH="${1:-$PROJECT_ROOT/.build/ReleaseDerivedData}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release-iphonesimulator/ParkNudge.app"
INFO_PLIST="$APP_PATH/Info.plist"
PLIST_BUDDY="${PARKNUDGE_PLISTBUDDY:-/usr/libexec/PlistBuddy}"

# Every check below fails closed. The earlier `find | grep -q` and bare
# `if rg ...` forms read a tool error as "nothing found": under pipefail a find
# error fails the pipeline, and rg exits 2 on an error and 127 when missing, so
# the audit could pass without having looked.

fail() {
  echo "$1" >&2
  exit 1
}

[[ -d "$APP_PATH" ]] || fail "Release app not found at $APP_PATH"
[[ -f "$INFO_PLIST" ]] || fail "Release app has no Info.plist at $INFO_PLIST"

storekit_match="$(find "$APP_PATH" -name '*.storekit' -print -quit)"
[[ -z "$storekit_match" ]] || fail "Release app contains a Debug StoreKit configuration: $storekit_match"

if "$PLIST_BUDDY" -c 'Print :UIBackgroundModes' "$INFO_PLIST" >/dev/null 2>&1; then
  fail "Release app unexpectedly declares UIBackgroundModes."
fi

if "$PLIST_BUDDY" -c 'Print :NSUserTrackingUsageDescription' "$INFO_PLIST" >/dev/null 2>&1; then
  fail "Release app unexpectedly declares tracking usage."
fi

# The built version and build must be the ones project.yml (canonical) names,
# so a stale DerivedData product or a pbxproj edited apart from project.yml
# cannot pass as the release candidate.
project_setting() {
  local key="$1" values
  values="$(sed -n "s/^[[:space:]]*$key:[[:space:]]*\"\{0,1\}\([^\"[:space:]]*\)\"\{0,1\}[[:space:]]*\$/\1/p" "$PROJECT_ROOT/project.yml")"
  [[ -n "$values" && "$(printf '%s\n' "$values" | wc -l | tr -d ' ')" -eq 1 ]] \
    || fail "project.yml must set $key exactly once (found: ${values:-none})"
  printf '%s' "$values"
}
expected_version="$(project_setting MARKETING_VERSION)"
expected_build="$(project_setting CURRENT_PROJECT_VERSION)"
built_version="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
built_build="$("$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$INFO_PLIST")"
[[ "$built_version" == "$expected_version" ]] \
  || fail "Release app version $built_version does not match project.yml MARKETING_VERSION $expected_version"
[[ "$built_build" == "$expected_build" ]] \
  || fail "Release app build $built_build does not match project.yml CURRENT_PROJECT_VERSION $expected_build"

sdk_status=0
rg -n -i 'Firebase|Amplitude|Mixpanel|FacebookSDK|AppsFlyer|Adjust SDK' "$PROJECT_ROOT/ParkNudge" || sdk_status=$?
case "$sdk_status" in
  0) fail "A forbidden analytics or advertising SDK marker was found." ;;
  1) ;; # no match
  *) fail "The SDK marker scan could not run (rg exit $sdk_status)." ;;
esac

lockfile_match="$(find "$PROJECT_ROOT" -name Package.resolved -print -quit)"
[[ -z "$lockfile_match" ]] || fail "A Swift package dependency lockfile was found ($lockfile_match); review dependency policy."

plutil -lint "$APP_PATH/PrivacyInfo.xcprivacy" >/dev/null
echo "Release audit passed: ParkNudge $built_version ($built_build); no StoreKit config, background modes, tracking prompt, third-party SDK marker, or package lockfile."
