#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="OpenGraphite"
BUNDLE_ID="dev.opengraphite.OpenGraphite"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
SAMPLE_PROJECT_PATH="$ROOT_DIR/SampleProject/OpenGraphiteSample.ogp"

OG_APP_NAME="$APP_NAME"
OG_BUNDLE_ID="$BUNDLE_ID"
source "$ROOT_DIR/Scripts/open_graphite_process.sh"

cd "$ROOT_DIR"

stop_running_open_graphite

xcodegen generate
xcodebuild \
  -project OpenGraphite.xcodeproj \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

"$ROOT_DIR/Scripts/sign_local_app.sh" "$APP_BUNDLE"

open_app() {
  /usr/bin/open \
    --env "OPENGRAPHITE_SAMPLE_PROJECT_PATH=$SAMPLE_PROJECT_PATH" \
    "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    OPENGRAPHITE_SAMPLE_PROJECT_PATH="$SAMPLE_PROJECT_PATH" \
      lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    wait_for_single_open_graphite
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
