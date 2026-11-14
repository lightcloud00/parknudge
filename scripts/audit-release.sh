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

# SuperwallKit 4.19.1 is the only approved package. Checkouts under DerivedData
# also contain Package.resolved files; only the app lockfile is the policy.
lockfile="$PROJECT_ROOT/ParkNudge.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
[[ -f "$lockfile" ]] || fail "Swift package lockfile is missing ($lockfile)."
python3 - "$lockfile" <<'PY' || fail "Package.resolved is not the approved SuperwallKit 4.19.1 pin."
import json, sys
pins = json.load(open(sys.argv[1])).get("pins") or []
found = {}
for pin in pins:
    identity = str(pin.get("identity", "")).lower()
    found[identity] = (pin.get("state") or {}).get("version")
expected = {
    "superwall-ios": "4.19.1",
    "superscript-ios-next": "1.0.18",
}
if found != expected:
    raise SystemExit(f"pins {found} != {expected}")
PY

key_status=0
rg -n 'pk_[A-Za-z0-9_-]{8,}' \
  "$PROJECT_ROOT/project.yml" \
  "$PROJECT_ROOT/ParkNudge/Info.plist" \
  "$PROJECT_ROOT/ParkNudge.xcodeproj/project.pbxproj" \
  "$PROJECT_ROOT/ParkNudge" \
  -g '!*.md' || key_status=$?
case "$key_status" in
  0) fail "A Superwall key value is committed." ;;
  1) ;;
  *) fail "The Superwall key scan could not run (rg exit $key_status)." ;;
esac

plutil -lint "$APP_PATH/PrivacyInfo.xcprivacy" >/dev/null
echo "Release audit passed: ParkNudge $built_version ($built_build); no StoreKit config, background modes, tracking prompt, or unapproved package."
