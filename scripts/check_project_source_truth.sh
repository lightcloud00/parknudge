#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root_dir"

# project.yml and its bounded post-generation hook own the release signing and
# StoreKit test configuration. This prevents a verify run from silently erasing
# pbxproj-only or xcscheme-only commerce state.
for literal in \
  'postGenCommand: python3 scripts/patch_storekit_test_scheme.py' \
  'CODE_SIGN_IDENTITY: Apple Distribution' \
  'CODE_SIGN_STYLE: Manual' \
  'DEVELOPMENT_TEAM: 9QCR933V26' \
  'PROVISIONING_PROFILE_SPECIFIER: ParkNudge App Store 2026-08-25'
do
  test "$(rg -F "$literal" project.yml | wc -l | tr -d ' ')" -eq 1
done

for literal in \
  'CODE_SIGN_IDENTITY = "Apple Distribution";' \
  'CODE_SIGN_STYLE = Manual;' \
  'DEVELOPMENT_TEAM = 9QCR933V26;' \
  'PROVISIONING_PROFILE_SPECIFIER = "ParkNudge App Store 2026-08-25";'
do
  test "$(rg -F "$literal" ParkNudge.xcodeproj/project.pbxproj | wc -l | tr -d ' ')" -eq 1
done

scheme_path='ParkNudge.xcodeproj/xcshareddata/xcschemes/ParkNudge.xcscheme'
test "$(rg -F '../../ParkNudge/Resources/ParkNudge.storekit' "$scheme_path" | wc -l | tr -d ' ')" -eq 2

test "$(rg -F 'url: https://github.com/superwall/Superwall-iOS' project.yml | wc -l | tr -d ' ')" -eq 1
test "$(rg -F 'exactVersion: 4.19.1' project.yml | wc -l | tr -d ' ')" -eq 1
test "$(rg -F 'SUPERWALL_PUBLIC_API_KEY: ""' project.yml | wc -l | tr -d ' ')" -eq 1

key_status=0
rg -n 'pk_[A-Za-z0-9_-]{8,}' project.yml ParkNudge/Info.plist ParkNudge.xcodeproj/project.pbxproj || key_status=$?
case "$key_status" in
  0)
    echo "A Superwall key value is committed." >&2
    exit 1
    ;;
  1) ;;
  *)
    echo "The Superwall key scan could not run (rg exit $key_status)." >&2
    exit 1
    ;;
esac

echo "ParkNudge generated-project source truth passed."
