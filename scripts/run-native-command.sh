#!/bin/bash
set -euo pipefail

# fleet-build owns outer serialization; every repository Xcode action still
# runs through the canonical workspace coordinator and its RAM gate.
exec /usr/bin/python3 \
  /Users/gus/.local/bin/ios_build_coordinator.py \
  -- "$@"
