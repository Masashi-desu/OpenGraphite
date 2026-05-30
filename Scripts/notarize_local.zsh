#!/usr/bin/env zsh

set -euo pipefail

source "${0:A:h}/release_common.zsh"
cd "${RELEASE_REPO_ROOT}"

print_usage() {
  cat <<'EOF'
Usage: ./Scripts/notarize_local.zsh [--skip-staple] [--skip-validate] <path-to-app-or-dmg>

Options:
  --skip-staple      Skip stapler staple after notarization.
  --skip-validate    Skip stapler validate / spctl verification.
  -h, --help         Show this help.
EOF
}

SKIP_STAPLE=0
SKIP_VALIDATE=0
TARGET_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-staple)
      SKIP_STAPLE=1
      shift
      ;;
    --skip-validate)
      SKIP_VALIDATE=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      if [[ -n "${TARGET_OVERRIDE}" ]]; then
        release_fail "対象ファイルは 1 つだけ指定してください。"
      fi
      TARGET_OVERRIDE="$1"
      shift
      ;;
  esac
done

release_load_env

if [[ -z "${TARGET_OVERRIDE}" ]]; then
  print_usage >&2
  exit 1
fi

TARGET="$(release_repo_path "${TARGET_OVERRIDE}")"
if [[ ! -e "${TARGET}" ]]; then
  release_fail "file not found: ${TARGET}"
fi

if ! xcrun notarytool --help >/dev/null 2>&1; then
  release_fail "notarytool が見つかりません。Xcode Command Line Tools をインストールしてください。"
fi

# .env に直接置いた Apple ID 認証を優先し、部分指定は設定漏れとして止める。
if [[ -n "${NOTARY_APPLE_ID:-}" || -n "${NOTARY_TEAM_ID:-}" || -n "${NOTARY_APP_PASSWORD:-}" ]]; then
  if [[ -z "${NOTARY_APPLE_ID:-}" || -z "${NOTARY_TEAM_ID:-}" || -z "${NOTARY_APP_PASSWORD:-}" ]]; then
    release_fail "Apple ID 認証を使う場合は NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_APP_PASSWORD をすべて設定してください。使わない場合はこれらを空にして NOTARY_PROFILE を設定してください。"
  fi
  release_step "notarytool へ申請します (Apple ID 環境変数)"
  xcrun notarytool submit "$TARGET" \
    --apple-id "${NOTARY_APPLE_ID}" \
    --team-id "${NOTARY_TEAM_ID}" \
    --password "${NOTARY_APP_PASSWORD}" \
    --wait
elif [[ -n "${NOTARY_PROFILE:-}" ]]; then
  release_step "notarytool へ申請します (keychain profile: ${NOTARY_PROFILE})"
  xcrun notarytool submit "$TARGET" --keychain-profile "$NOTARY_PROFILE" --wait
else
  release_fail "NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_APP_PASSWORD もしくは NOTARY_PROFILE を設定してください。"
fi

if [[ "${SKIP_STAPLE}" -ne 1 ]]; then
  release_step "stapler でチケットを付与します"
  xcrun stapler staple "$TARGET"
fi

if [[ "${SKIP_VALIDATE}" -ne 1 ]]; then
  local_assess_type="open"
  typeset -a spctl_args
  if [[ -d "${TARGET}" && "${TARGET}" == *.app ]]; then
    local_assess_type="execute"
  fi

  if [[ "${SKIP_STAPLE}" -ne 1 ]]; then
    release_step "stapler validate で検証します"
    xcrun stapler validate "$TARGET"
  fi

  release_step "spctl で Gatekeeper 判定を確認します"
  spctl_args=(--assess --type "${local_assess_type}" -v)
  if [[ ! -d "${TARGET}" ]]; then
    spctl_args+=(--context context:primary-signature)
  fi
  spctl "${spctl_args[@]}" "$TARGET"
fi

echo "Done: ${TARGET}"
