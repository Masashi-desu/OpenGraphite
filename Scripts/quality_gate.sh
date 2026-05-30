#!/usr/bin/env zsh

set -euo pipefail

cd "$(dirname "$0")/.."

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
