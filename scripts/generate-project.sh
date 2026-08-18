#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

command -v xcodegen >/dev/null || {
  echo "XcodeGen is required (minimum 2.45.0)." >&2
  exit 1
}

fingerprint_project() {
  find ParkNudge.xcodeproj -type f ! -path '*/xcuserdata/*' -print0 \
    | sort -z \
    | xargs -0 shasum -a 256 \
    | shasum -a 256 \
    | awk '{print $1}'
}

xcodegen generate --spec project.yml
FIRST_FINGERPRINT="$(fingerprint_project)"
xcodegen generate --spec project.yml
SECOND_FINGERPRINT="$(fingerprint_project)"

if [[ "$FIRST_FINGERPRINT" != "$SECOND_FINGERPRINT" ]]; then
  echo "XcodeGen output changed on the second generation." >&2
  exit 1
fi

echo "Xcode project generation is idempotent: $SECOND_FINGERPRINT"
