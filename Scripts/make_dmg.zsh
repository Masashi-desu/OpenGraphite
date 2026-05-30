#!/usr/bin/env zsh

set -euo pipefail
setopt null_glob

source "${0:A:h}/release_common.zsh"
cd "${RELEASE_REPO_ROOT}"

print_usage() {
  cat <<'EOF'
Usage: ./Scripts/make_dmg.zsh [--app-path <path>] [--output-dir <dir>]

Options:
  --app-path <path>   Target .app path. Falls back to APP_PATH or default Release build output.
  --output-dir <dir>  Output directory for the generated DMG. Default: RELEASE_OUTPUT_DIR or dist.
  -h, --help          Show this help.
EOF
}

APP_PATH_OVERRIDE=""
OUTPUT_DIR_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-path)
      [[ $# -ge 2 ]] || release_fail "--app-path には値が必要です。"
      APP_PATH_OVERRIDE="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || release_fail "--output-dir には値が必要です。"
      OUTPUT_DIR_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      release_fail "Unknown option: $1"
      ;;
  esac
done

release_load_env

release_require_command "create-dmg" $'create-dmg が見つかりません。以下でインストールしてください:\n  brew install create-dmg'

APP_PATH="${APP_PATH_OVERRIDE:-${APP_PATH:-}}"
OUTPUT_DIR="${OUTPUT_DIR_OVERRIDE:-${OUTPUT_DIR:-${RELEASE_OUTPUT_DIR:-dist}}}"

DMG_WINDOW_WIDTH="${DMG_WINDOW_WIDTH:-980}"
DMG_WINDOW_HEIGHT="${DMG_WINDOW_HEIGHT:-610}"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-128}"
DMG_TEXT_SIZE="${DMG_TEXT_SIZE:-16}"
DMG_APP_ICON_X="${DMG_APP_ICON_X:-164}"
DMG_APP_ICON_Y="${DMG_APP_ICON_Y:-225}"
DMG_APPLICATIONS_X="${DMG_APPLICATIONS_X:-784}"
DMG_APPLICATIONS_Y="${DMG_APPLICATIONS_Y:-225}"

if [[ -z "${APP_PATH}" ]]; then
  if APP_PATH="$(release_find_default_app)"; then
    :
  else
    release_fail ".app が見つかりません。--app-path / APP_PATH で明示するか、先に Release ビルドしてください。"
  fi
else
  APP_PATH="$(release_repo_path "${APP_PATH}")"
fi

if [[ ! -d "${APP_PATH}" ]]; then
  release_fail "APP_PATH='${APP_PATH}' は .app フォルダではありません。"
fi

INFO_PLIST="${APP_PATH}/Contents/Info.plist"
if [[ ! -f "${INFO_PLIST}" ]]; then
  release_fail "Info.plist が見つかりません: ${INFO_PLIST}"
fi

OUTPUT_DIR="$(release_repo_path "${OUTPUT_DIR}")"
mkdir -p "${OUTPUT_DIR}"

BUNDLE_NAME="$(release_app_bundle_name "${APP_PATH}")"
OUT_PATH="$(release_dmg_output_path "${APP_PATH}" "${OUTPUT_DIR}")"

typeset -a BG_ARGS
BG_OUTPUT_PATH="${RELEASE_REPO_ROOT}/build/dmg/background@2x.png"
release_step "DMG 背景を生成します"
xcrun swift "${RELEASE_SCRIPT_DIR}/generate_dmg_background.swift" "${BG_OUTPUT_PATH}" "${BUNDLE_NAME}"
BG_ARGS=(--background "${BG_OUTPUT_PATH}")

[[ -f "${OUT_PATH}" ]] && rm -f "${OUT_PATH}"

release_step "DMG を作成します: ${OUT_PATH}"
create-dmg \
  --volname "${BUNDLE_NAME}" \
  --window-pos 200 120 \
  --window-size "${DMG_WINDOW_WIDTH}" "${DMG_WINDOW_HEIGHT}" \
  --text-size "${DMG_TEXT_SIZE}" \
  --icon-size "${DMG_ICON_SIZE}" \
  --icon "$(basename "${APP_PATH}")" "${DMG_APP_ICON_X}" "${DMG_APP_ICON_Y}" \
  --app-drop-link "${DMG_APPLICATIONS_X}" "${DMG_APPLICATIONS_Y}" \
  "${BG_ARGS[@]}" \
  "${OUT_PATH}" \
  "${APP_PATH}"

echo "OK: ${OUT_PATH}"
