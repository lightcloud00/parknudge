#!/bin/bash
set -euo pipefail

# This shared-Mac route waits for capacity and lets the coordinator own Xcode.
exec /usr/bin/python3 \
  /Users/gus/.codex/skills/ios-build-admission/scripts/wait_for_ios_build_admission.py \
  --max-wait-seconds 600 --interval-seconds 60 -- \
  /usr/bin/python3 /Users/gus/Desktop/Claudecode/scripts/ios_build_coordinator.py \
  -- "$@"
