#!/usr/bin/env zsh

# リリース関連スクリプトの共通設定と補助関数をまとめる。
if [[ -n "${RELEASE_COMMON_LOADED:-}" && -n "${RELEASE_REPO_ROOT:-}" && -n "${RELEASE_SCRIPT_DIR:-}" ]]; then
  return 0
fi
RELEASE_COMMON_LOADED=1

typeset -gr RELEASE_COMMON_PATH="${(%):-%N}"
typeset -gr RELEASE_SCRIPT_DIR="$(cd "$(dirname "${RELEASE_COMMON_PATH}")" >/dev/null 2>&1 && pwd)"
typeset -gr RELEASE_REPO_ROOT="$(cd "${RELEASE_SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

# 手順の切り替わりをログで追いやすくする。
function release_step() {
  echo ""
  echo "==> $1"
}

# 失敗時の表示を統一する。
function release_fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# リポジトリ相対パスを絶対パスへそろえる。
function release_repo_path() {
  local candidate="$1"

  if [[ -z "${candidate}" ]]; then
    release_fail "空のパスは解決できません。"
  fi

  if [[ "${candidate}" = /* ]]; then
    echo "${candidate}"
  else
    echo "${RELEASE_REPO_ROOT}/${candidate}"
  fi
}

# 必要コマンドの存在確認をまとめる。
function release_require_command() {
  local command_name="$1"
  local error_message="${2:-${command_name} が見つかりません。}"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    release_fail "${error_message}"
  fi
}

# リリース設定はリポジトリ直下の .env だけを正本として扱う。
function release_load_env() {
  local env_file="${RELEASE_REPO_ROOT}/.env"

  if [[ "${RELEASE_ENV_FILE:-}" == "${env_file}" ]]; then
    return 0
  fi

  if [[ -f "${env_file}" ]]; then
    echo "Loading env file: ${env_file}"
    set -a
    source "${env_file}"
    set +a
    export RELEASE_ENV_FILE="${env_file}"
  fi

  return 0
}

# 既定の Release 生成物から .app を見つける。
function release_find_default_app() {
  setopt localoptions null_glob

  local -a search_globs=(
    "${RELEASE_REPO_ROOT}/build/Release/*.app"
    "${RELEASE_REPO_ROOT}/build/ReleaseDerivedData/Build/Products/Release/*.app"
    "${RELEASE_REPO_ROOT}/build/Build/Products/Release/*.app"
  )
  local glob=""
  local candidate=""

  for glob in "${search_globs[@]}"; do
    for candidate in ${~glob}; do
      if [[ -d "${candidate}" ]]; then
        echo "${candidate}"
        return 0
      fi
    done
  done

  return 1
}

# Plist 値の取得を呼び出し側から隠蔽する。
function release_read_plist_value() {
  local plist_path="$1"
  local key="$2"

  /usr/libexec/PlistBuddy -c "Print :${key}" "${plist_path}" 2>/dev/null || true
}

# .app から配布名を決める。
function release_app_bundle_name() {
  local app_path="$1"
  local info_plist="${app_path}/Contents/Info.plist"
  local bundle_name=""

  bundle_name="$(release_read_plist_value "${info_plist}" "CFBundleName")"
  if [[ -z "${bundle_name}" ]]; then
    bundle_name="$(basename "${app_path}" .app)"
  fi

  echo "${bundle_name}"
}

# .app からバージョンを決める。
function release_app_version() {
  local app_path="$1"
  local info_plist="${app_path}/Contents/Info.plist"
  local version=""

  version="$(release_read_plist_value "${info_plist}" "CFBundleShortVersionString")"
  if [[ -z "${version}" ]]; then
    version="0.0.0"
  fi

  echo "${version}"
}

# DMG の出力先を .app から一意に決める。
function release_dmg_output_path() {
  local app_path="$1"
  local output_dir="$2"
  local bundle_name=""
  local version=""

  bundle_name="$(release_app_bundle_name "${app_path}")"
  version="$(release_app_version "${app_path}")"

  echo "${output_dir}/${bundle_name}-${version}.dmg"
}
