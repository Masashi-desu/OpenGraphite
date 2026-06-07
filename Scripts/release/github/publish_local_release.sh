#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

REMOTE="${REMOTE:-origin}"
DEV_BRANCH="${DEV_BRANCH:-dev}"
BASE_REF="${BASE_REF:-${REMOTE}/main}"
HEAD_REF="${HEAD_REF:-HEAD}"
RELEASE_APP_NAME="${RELEASE_APP_NAME:-OpenGraphite}"
DMG_PATH="${DMG_PATH:-}"
GH_REPO="${GH_REPO:-}"
PUSH_MAIN=0

usage() {
  cat <<'EOF'
Usage: Scripts/release/github/publish_local_release.sh [options]

Create the GitHub Release/tag from the current dev commit and upload the local
signed/notarized DMG without adding the DMG to Git.

Options:
  --dmg <path>       DMG path. Defaults to dist/<app-name>-<version>.dmg.
  --repo <owner/repo>
                    GitHub repository for gh release commands.
  --push-main        Push the current dev commit to main after release creation.
  -h, --help         Show this help.

Environment:
  RELEASE_APP_NAME  App/DMG basename. Default: OpenGraphite.
  REMOTE            Git remote. Default: origin.
  DEV_BRANCH        Release preparation branch. Default: dev.
  BASE_REF          Base ref for branch policy. Default: origin/main.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg)
      DMG_PATH="${2:-}"
      shift 2
      ;;
    --repo)
      GH_REPO="${2:-}"
      shift 2
      ;;
    --push-main)
      PUSH_MAIN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v gh >/dev/null 2>&1 || fail "GitHub CLI 'gh' が見つかりません。"
gh auth status >/dev/null 2>&1 || fail "GitHub CLI 'gh' が認証されていません。"

current_branch="$(git branch --show-current)"
[[ "${current_branch}" == "${DEV_BRANCH}" ]] || fail "release は ${DEV_BRANCH} ブランチ上で実行してください。current=${current_branch}"

git diff --quiet || fail "未コミットの変更があります。release 対象 commit を確定してから実行してください。"
git diff --cached --quiet || fail "staged の未コミット変更があります。release 対象 commit を確定してから実行してください。"
untracked_files="$(git ls-files --others --exclude-standard)"
[[ -z "${untracked_files}" ]] || fail "未追跡ファイルがあります。release 対象 commit に含めるか ignore してください。"$'\n'"${untracked_files}"

git fetch "${REMOTE}" \
  "+refs/heads/main:refs/remotes/${REMOTE}/main" \
  "+refs/heads/${DEV_BRANCH}:refs/remotes/${REMOTE}/${DEV_BRANCH}" \
  --tags

head_sha="$(git rev-parse --verify "${HEAD_REF}^{commit}")"
remote_dev_sha="$(git rev-parse --verify "${REMOTE}/${DEV_BRANCH}^{commit}")"
[[ "${head_sha}" == "${remote_dev_sha}" ]] || fail "${DEV_BRANCH} を先に push し、CI テスト成功を確認してください。HEAD=${head_sha}, ${REMOTE}/${DEV_BRANCH}=${remote_dev_sha}"

metadata_file="$(mktemp)"
cleanup() {
  rm -f "${metadata_file}" "${release_notes:-}"
}
trap cleanup EXIT

GITHUB_OUTPUT="${metadata_file}" \
  BASE_REF="${BASE_REF}" \
  HEAD_REF="${HEAD_REF}" \
  ./Scripts/release/github/check_release_branch_policy.sh

version=""
build=""
release_tag=""
while IFS='=' read -r key value; do
  case "${key}" in
    version) version="${value}" ;;
    build) build="${value}" ;;
    tag) release_tag="${value}" ;;
  esac
done < "${metadata_file}"

[[ -n "${version}" ]] || fail "release version を取得できません。"
[[ -n "${build}" ]] || fail "release build を取得できません。"
[[ -n "${release_tag}" ]] || fail "release tag を取得できません。"

if [[ -z "${DMG_PATH}" ]]; then
  DMG_PATH="dist/${RELEASE_APP_NAME}-${version}.dmg"
fi
[[ -f "${DMG_PATH}" ]] || fail "DMG が見つかりません: ${DMG_PATH}"

if [[ -z "${GH_REPO}" ]]; then
  GH_REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi

if git ls-remote --exit-code --tags "${REMOTE}" "refs/tags/${release_tag}" >/dev/null 2>&1; then
  fail "remote tag が既に存在します: ${release_tag}"
fi
if gh release view "${release_tag}" --repo "${GH_REPO}" >/dev/null 2>&1; then
  fail "GitHub Release が既に存在します: ${release_tag}"
fi

dmg_sha256="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
release_notes="$(mktemp)"
cat > "${release_notes}" <<EOF
${RELEASE_APP_NAME} ${version} (${build})

- Commit: ${head_sha}
- DMG SHA256: ${dmg_sha256}
EOF

echo "Creating ${release_tag} from ${head_sha}"
echo "Uploading ${DMG_PATH}"
gh release create "${release_tag}" "${DMG_PATH}" \
  --repo "${GH_REPO}" \
  --target "${head_sha}" \
  --title "${RELEASE_APP_NAME} ${version} (${build})" \
  --notes-file "${release_notes}" \
  --latest

echo "GitHub Release created: ${release_tag}"
echo "DMG SHA256: ${dmg_sha256}"

if (( PUSH_MAIN == 1 )); then
  git push "${REMOTE}" "HEAD:refs/heads/main"
  echo "Pushed ${DEV_BRANCH} to main."
else
  echo "Next: git push ${REMOTE} HEAD:refs/heads/main"
fi
