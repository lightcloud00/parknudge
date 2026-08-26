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

echo "ParkNudge generated-project source truth passed."
