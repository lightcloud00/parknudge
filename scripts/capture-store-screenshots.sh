#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

test -z "$(git status --porcelain --untracked-files=all)" || {
  echo "Screenshot capture requires a clean exact-head worktree" >&2
  exit 1
}

destination="${PARKNUDGE_SCREENSHOT_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5}"
expected_width="${PARKNUDGE_SCREENSHOT_WIDTH:-1320}"
expected_height="${PARKNUDGE_SCREENSHOT_HEIGHT:-2868}"
output_root="${PARKNUDGE_SCREENSHOT_OUTPUT_ROOT:-$repo_root/artifacts}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
source_sha="$(git rev-parse HEAD)"
source_tree_sha="$(git rev-parse 'HEAD^{tree}')"
output_dir="$output_root/store-screenshots-$stamp"
derived_data="$output_dir/DerivedData"
result_bundle="$output_dir/ParkNudge-Store-Screenshots.xcresult"
summary="$output_dir/test-summary.json"
export_dir="$output_dir/exported"
staging_dir="$output_dir/staged"
coordinator=(/usr/bin/python3 /Users/gus/Desktop/Claudecode/scripts/ios_build_coordinator.py --)
ffmpeg_bin="${PARKNUDGE_FFMPEG_BIN:-/Users/gus/.local/bin/ffmpeg}"

case "$output_root" in
  /*) ;;
  *) echo "PARKNUDGE_SCREENSHOT_OUTPUT_ROOT must be absolute" >&2; exit 64 ;;
esac
test -x "$ffmpeg_bin" || {
  echo "ffmpeg is required to normalize screenshots to opaque RGB PNGs: $ffmpeg_bin" >&2
  exit 69
}

./scripts/generate-project.sh
test -z "$(git status --porcelain --untracked-files=all)" || {
  echo "Generated Xcode project does not match committed source" >&2
  exit 1
}

mkdir -p "$export_dir" "$staging_dir"
"${coordinator[@]}" test \
  -project ParkNudge.xcodeproj \
  -scheme ParkNudge \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -resultBundlePath "$result_bundle" \
  -only-testing:ParkNudgeUITests/ParkNudgeStoreScreenshotTests/testCaptureStoreScreenshots \
  CODE_SIGNING_ALLOWED=NO

xcrun xcresulttool get test-results summary --path "$result_bundle" --compact > "$summary"
jq -e '.result == "Passed" and .failedTests == 0 and .skippedTests == 0 and .totalTestCount == 1 and .passedTests == 1' "$summary" >/dev/null
xcrun xcresulttool export attachments --path "$result_bundle" --output-path "$export_dir"

captures=(
  "01-save-where-you-parked:01-save-where-you-parked.png"
  "02-add-a-photo-note-or-cost:02-add-a-photo-note-or-cost.png"
  "03-set-a-return-reminder:03-set-a-return-reminder.png"
  "04-navigate-back-to-your-car:04-navigate-back-to-your-car.png"
  "05-keep-location-data-private:05-keep-location-data-private.png"
)

for mapping in "${captures[@]}"; do
  attachment_name="${mapping%%:*}"
  filename="${mapping#*:}"
  exported_file="$(jq -r --arg name "$attachment_name" '[.[] | .attachments[]? | select(.suggestedHumanReadableName == $name or .suggestedHumanReadableName == ($name + ".png")) | .exportedFileName] | if length == 1 then .[0] else empty end' "$export_dir/manifest.json")"
  test -n "$exported_file" || {
    echo "Expected exactly one attachment named $attachment_name" >&2
    exit 1
  }
  "$ffmpeg_bin" -y -hide_banner -loglevel error \
    -i "$export_dir/$exported_file" \
    -frames:v 1 -pix_fmt rgb24 "$staging_dir/$filename"
  width="$(sips -g pixelWidth "$staging_dir/$filename" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$staging_dir/$filename" | awk '/pixelHeight/ {print $2}')"
  has_alpha="$(sips -g hasAlpha "$staging_dir/$filename" | awk '/hasAlpha/ {print $2}')"
  test "$width" = "$expected_width" && test "$height" = "$expected_height" || {
    echo "$filename is ${width}x${height}; expected ${expected_width}x${expected_height}" >&2
    exit 1
  }
  test "$has_alpha" = "no" || {
    echo "$filename unexpectedly contains alpha" >&2
    exit 1
  }
done

receipt="$output_dir/receipt.txt"
{
  printf 'schema=parknudge.store-screenshots.v1\n'
  printf 'captured_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'source_sha=%s\nsource_tree_sha=%s\n' "$source_sha" "$source_tree_sha"
  printf 'device_class=iphone-6.9\n'
  printf 'destination=%s\nwidth=%s\nheight=%s\n' "$destination" "$expected_width" "$expected_height"
  printf 'result_bundle=%s\nsummary=%s\nstaging_dir=%s\n' "$result_bundle" "$summary" "$staging_dir"
  for mapping in "${captures[@]}"; do
    filename="${mapping#*:}"
    printf '%s_sha256=%s\n' "$filename" "$(shasum -a 256 "$staging_dir/$filename" | awk '{print $1}')"
  done
} | tee "$receipt"

test -z "$(git status --porcelain --untracked-files=all)" || {
  echo "Capture changed tracked source state" >&2
  exit 1
}

printf 'ParkNudge screenshot capture staged five verified images: %s\n' "$receipt"
