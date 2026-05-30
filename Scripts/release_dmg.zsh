#!/usr/bin/env zsh

set -euo pipefail

source "${0:A:h}/release_common.zsh"
cd "${RELEASE_REPO_ROOT}"

print_usage() {
  cat <<'EOF'
Usage: ./Scripts/release_dmg.zsh [options]

Options:
  --app-path <path>   Reuse an existing .app instead of the default Release build output.
  --output-dir <dir>  Output directory for the generated DMG. Default: RELEASE_OUTPUT_DIR or dist.
  --build             Force a fresh Release build even when APP_PATH is given.
  --skip-build        Skip the build step and require an existing .app.
  --skip-sign         Skip the codesign step.
  --skip-notarize     Skip app / DMG notarization after signing.
  -h, --help          Show this help.
EOF
}

# Release ビルドを再現可能にするため、xcodegen と xcodebuild を直列で実行する。
function build_release_app() {
  local derived_data_path="$1"

  release_require_command "xcodegen" "xcodegen が見つかりません。"
  release_step "xcodegen generate"
  xcodegen generate

  release_step "Release ビルドを実行します"
  xcodebuild \
    -project OpenGraphite.xcodeproj \
    -scheme "${RELEASE_SCHEME}" \
    -configuration "${RELEASE_CONFIGURATION}" \
    -destination "${RELEASE_DESTINATION}" \
    -derivedDataPath "${derived_data_path}" \
    CODE_SIGNING_ALLOWED=NO \
    build
}

# 公証前提の配布に必要な署名を .app へ付与する。
function sign_app() {
  local app_path="$1"
  local entitlements_path="${CODESIGN_ENTITLEMENTS:-}"
  local -a codesign_args

  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    release_fail "CODESIGN_IDENTITY が未設定です。.env に Developer ID Application を設定してください。"
  fi

  if [[ "${CODESIGN_IDENTITY}" == "-" && "${SKIP_NOTARIZE}" -ne 1 ]]; then
    release_fail "公証する場合は ad hoc 署名を使えません。CODESIGN_IDENTITY に Developer ID Application を設定してください。"
  fi

  codesign_args=(--force --deep --sign "${CODESIGN_IDENTITY}")

  if [[ "${CODESIGN_IDENTITY}" != "-" ]]; then
    codesign_args+=(--options "${CODESIGN_OPTIONS}")
    if [[ "${CODESIGN_TIMESTAMP}" -ne 0 ]]; then
      codesign_args+=(--timestamp)
    fi
  fi

  if [[ -n "${entitlements_path}" ]]; then
    entitlements_path="$(release_repo_path "${entitlements_path}")"
    [[ -f "${entitlements_path}" ]] || release_fail "entitlements が見つかりません: ${entitlements_path}"
    codesign_args+=(--entitlements "${entitlements_path}")
  fi

  release_step "アプリへコード署名を付与します"
  codesign "${codesign_args[@]}" "${app_path}"
}

# codesign の整合性確認をまとめて扱う。
function verify_signature() {
  local app_path="$1"

  release_step "コード署名を検証します"
  codesign --verify --deep --strict --verbose=2 "${app_path}"
}

# DMG は Gatekeeper 評価対象になるため、公証前に Developer ID 署名を付与する。
function sign_dmg() {
  local dmg_path="$1"
  local -a codesign_args

  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    release_fail "CODESIGN_IDENTITY が未設定です。.env に Developer ID Application を設定してください。"
  fi

  if [[ "${CODESIGN_IDENTITY}" == "-" ]]; then
    release_fail "公証する DMG には ad hoc 署名を使えません。CODESIGN_IDENTITY に Developer ID Application を設定してください。"
  fi

  codesign_args=(--force --sign "${CODESIGN_IDENTITY}")
  if [[ "${CODESIGN_TIMESTAMP}" -ne 0 ]]; then
    codesign_args+=(--timestamp)
  fi

  release_step "DMG へコード署名を付与します"
  codesign "${codesign_args[@]}" "${dmg_path}"
}

# DMG 自体の署名を検証し、未署名のまま公証へ進めないようにする。
function verify_dmg_signature() {
  local dmg_path="$1"

  release_step "DMG のコード署名を検証します"
  codesign --verify --verbose=2 "${dmg_path}"
}

# 公証前に Developer ID Application 署名であることを確認する。
function require_developer_id_signature() {
  local app_path="$1"
  local signature_info=""

  signature_info="$(codesign -dv --verbose=4 "${app_path}" 2>&1 || true)"
  if ! printf '%s\n' "${signature_info}" | grep -q '^Authority=Developer ID Application:'; then
    release_fail "公証対象の .app が Developer ID Application 署名になっていません。CODESIGN_IDENTITY を設定するか、署名済みアプリを指定してください。"
  fi
}

# DMG へ入れる前に .app 自体も公証し、チケットを埋め込む。
function notarize_app_bundle() {
  local app_path="$1"
  local temp_dir=""
  local archive_path=""

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/release-app-notary.XXXXXX")"
  archive_path="${temp_dir}/$(basename "${app_path}").zip"

  release_step "アプリ単体の公証用 ZIP を作成します"
  ditto -c -k --keepParent "${app_path}" "${archive_path}"

  "${RELEASE_SCRIPT_DIR}/notarize_local.zsh" --skip-staple --skip-validate "${archive_path}"

  release_step "アプリへ公証チケットを付与します"
  xcrun stapler staple "${app_path}"

  release_step "アプリの公証チケットを検証します"
  xcrun stapler validate "${app_path}"

  release_step "アプリ単体の Gatekeeper 判定を確認します"
  spctl --assess --type execute -v "${app_path}"

  rm -rf "${temp_dir}"
}

# 最終DMGをマウントし、内包された .app もチケット付きで通ることを確認する。
function verify_app_inside_dmg() {
  local dmg_path="$1"
  local app_name="$2"
  local mount_point=""
  local app_in_dmg=""

  mount_point="$(mktemp -d "${TMPDIR:-/tmp}/release-dmg-verify.XXXXXX")"

  release_step "DMG 内のアプリ公証状態を検証します"
  {
    hdiutil attach "${dmg_path}" -readonly -nobrowse -mountpoint "${mount_point}" >/dev/null
    app_in_dmg="${mount_point}/${app_name}"
    [[ -d "${app_in_dmg}" ]] || release_fail "DMG 内に ${app_name} が見つかりません。"
    xcrun stapler validate "${app_in_dmg}"
    spctl --assess --type execute -v "${app_in_dmg}"
  } always {
    hdiutil detach "${mount_point}" >/dev/null 2>&1 || true
    rmdir "${mount_point}" >/dev/null 2>&1 || true
  }
}

APP_PATH_OVERRIDE=""
OUTPUT_DIR_OVERRIDE=""
FORCE_BUILD=0
SKIP_BUILD_FLAG=0
SKIP_SIGN_FLAG=0
SKIP_NOTARIZE_FLAG=0

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
    --build)
      FORCE_BUILD=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD_FLAG=1
      shift
      ;;
    --skip-sign)
      SKIP_SIGN_FLAG=1
      shift
      ;;
    --skip-notarize)
      SKIP_NOTARIZE_FLAG=1
      shift
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

APP_PATH="${APP_PATH_OVERRIDE:-${APP_PATH:-}}"
OUTPUT_DIR="${OUTPUT_DIR_OVERRIDE:-${OUTPUT_DIR:-${RELEASE_OUTPUT_DIR:-dist}}}"
RELEASE_SCHEME="${RELEASE_SCHEME:-OpenGraphite}"
RELEASE_CONFIGURATION="${RELEASE_CONFIGURATION:-Release}"
RELEASE_DESTINATION="${RELEASE_DESTINATION:-platform=macOS}"
RELEASE_DERIVED_DATA_PATH="$(release_repo_path "${RELEASE_DERIVED_DATA_PATH:-build}")"
CODESIGN_ENTITLEMENTS="${CODESIGN_ENTITLEMENTS:-}"
CODESIGN_OPTIONS="${CODESIGN_OPTIONS:-runtime}"
CODESIGN_TIMESTAMP="${CODESIGN_TIMESTAMP:-1}"
SKIP_SIGN="${RELEASE_SKIP_SIGN:-0}"
SKIP_NOTARIZE="${RELEASE_SKIP_NOTARIZE:-0}"

if [[ "${SKIP_SIGN_FLAG}" -eq 1 ]]; then
  SKIP_SIGN=1
fi
if [[ "${SKIP_NOTARIZE_FLAG}" -eq 1 ]]; then
  SKIP_NOTARIZE=1
fi

if [[ "${FORCE_BUILD}" -eq 1 && "${SKIP_BUILD_FLAG}" -eq 1 ]]; then
  release_fail "--build と --skip-build は同時に指定できません。"
fi

if [[ "${FORCE_BUILD}" -eq 1 ]]; then
  SHOULD_BUILD=1
elif [[ "${SKIP_BUILD_FLAG}" -eq 1 ]]; then
  SHOULD_BUILD=0
elif [[ -z "${APP_PATH}" ]]; then
  SHOULD_BUILD=1
else
  SHOULD_BUILD=0
fi

if [[ "${SHOULD_BUILD}" -eq 1 ]]; then
  build_release_app "${RELEASE_DERIVED_DATA_PATH}"
  APP_PATH="$(release_find_default_app)" || release_fail "Release ビルド後の .app が見つかりません。"
elif [[ -n "${APP_PATH}" ]]; then
  APP_PATH="$(release_repo_path "${APP_PATH}")"
else
  release_fail ".app が指定されていません。--app-path を指定するか、build を有効にしてください。"
fi

[[ -d "${APP_PATH}" ]] || release_fail "APP_PATH='${APP_PATH}' は .app フォルダではありません。"

if [[ "${SKIP_SIGN}" -ne 1 ]]; then
  sign_app "${APP_PATH}"
  verify_signature "${APP_PATH}"
else
  release_step "コード署名と署名検証をスキップします"
fi

if [[ "${SKIP_NOTARIZE}" -ne 1 ]]; then
  require_developer_id_signature "${APP_PATH}"
  notarize_app_bundle "${APP_PATH}"
fi

DMG_PATH="$(release_dmg_output_path "${APP_PATH}" "$(release_repo_path "${OUTPUT_DIR}")")"

typeset -a MAKE_DMG_ARGS
typeset -a NOTARIZE_ARGS
MAKE_DMG_ARGS=(--app-path "${APP_PATH}" --output-dir "${OUTPUT_DIR}")
NOTARIZE_ARGS=("${DMG_PATH}")

"${RELEASE_SCRIPT_DIR}/make_dmg.zsh" "${MAKE_DMG_ARGS[@]}"

if [[ "${SKIP_NOTARIZE}" -ne 1 ]]; then
  sign_dmg "${DMG_PATH}"
  verify_dmg_signature "${DMG_PATH}"
elif [[ "${SKIP_SIGN}" -ne 1 && "${CODESIGN_IDENTITY}" != "-" ]]; then
  sign_dmg "${DMG_PATH}"
  verify_dmg_signature "${DMG_PATH}"
fi

if [[ "${SKIP_NOTARIZE}" -ne 1 ]]; then
  "${RELEASE_SCRIPT_DIR}/notarize_local.zsh" "${NOTARIZE_ARGS[@]}"
  verify_app_inside_dmg "${DMG_PATH}" "$(basename "${APP_PATH}")"
fi

echo ""
echo "Release artifact: ${DMG_PATH}"
