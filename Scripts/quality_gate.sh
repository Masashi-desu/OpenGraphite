#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OG_APP_NAME="OpenGraphite"
OG_BUNDLE_ID="dev.opengraphite.OpenGraphite"
source "$ROOT_DIR/Scripts/open_graphite_process.sh"

cd "$ROOT_DIR"

if [[ "$(open_graphite_process_count)" != "0" ]]; then
  echo "==> stop running OpenGraphite before tests"
  stop_running_open_graphite
fi

echo "==> xcodegen generate"
xcodegen generate

echo "==> xcodebuild test"
xcodebuild \
  -project OpenGraphite.xcodeproj \
  -scheme OpenGraphite \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test

echo "==> xcodebuild build ogkiln"
xcodebuild \
  -project OpenGraphite.xcodeproj \
  -scheme ogkiln \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> ogkiln validate sample"
./Scripts/ogkiln validate SampleProject/OpenGraphiteSample.ogp --json >/dev/null
