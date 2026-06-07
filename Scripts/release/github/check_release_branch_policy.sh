#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${BASE_REF:-${1:-origin/main}}"
HEAD_REF="${HEAD_REF:-${2:-origin/dev}}"
PROJECT_FILE="${PROJECT_FILE:-project.yml}"
REQUIRE_HEAD_REF="${REQUIRE_HEAD_REF:-}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

resolve_commit() {
  local ref="$1"
  git rev-parse --verify "${ref}^{commit}" 2>/dev/null || fail "参照を解決できません: ${ref}"
}

release_metadata() {
  local ref="$1"

  git cat-file -e "${ref}:${PROJECT_FILE}" 2>/dev/null || fail "${ref} に ${PROJECT_FILE} が存在しません。"
  git show "${ref}:${PROJECT_FILE}" | awk '
    function clean(value) {
      sub(/^[^:]+:[[:space:]]*/, "", value)
      sub(/[[:space:]]+#.*$/, "", value)
      gsub(/["'\''[:space:]]/, "", value)
      return value
    }
    /^[[:space:]]*MARKETING_VERSION:[[:space:]]*/ {
      marketing = clean($0)
    }
    /^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*/ {
      build = clean($0)
    }
    END {
      if (marketing == "" || build == "") {
        exit 1
      }
      printf "%s\t%s\n", marketing, build
    }
  ' || fail "${ref}:${PROJECT_FILE} からバージョン情報を取得できません。"
}

format_metadata() {
  local metadata="$1"
  local version="${metadata%%$'\t'*}"
  local build="${metadata##*$'\t'}"
  printf "%s (%s)" "${version}" "${build}"
}

BASE_SHA="$(resolve_commit "${BASE_REF}")"
HEAD_SHA="$(resolve_commit "${HEAD_REF}")"

if [[ "${BASE_SHA}" == "${HEAD_SHA}" ]]; then
  fail "dev と main の差分がありません。main に存在しないリリースが dev に 1 つ必要です。"
fi

if [[ -n "${REQUIRE_HEAD_REF}" ]]; then
  REQUIRED_HEAD_SHA="$(resolve_commit "${REQUIRE_HEAD_REF}")"
  if [[ "${HEAD_SHA}" != "${REQUIRED_HEAD_SHA}" ]]; then
    fail "main への release push は ${REQUIRE_HEAD_REF} と同じコミットである必要があります。HEAD=${HEAD_SHA}, ${REQUIRE_HEAD_REF}=${REQUIRED_HEAD_SHA}"
  fi
fi

git merge-base --is-ancestor "${BASE_SHA}" "${HEAD_SHA}" || fail "${HEAD_REF} は ${BASE_REF} から fast-forward できる履歴ではありません。"

BASE_METADATA="$(release_metadata "${BASE_SHA}")"
HEAD_METADATA="$(release_metadata "${HEAD_SHA}")"
BASE_BUILD="${BASE_METADATA##*$'\t'}"
HEAD_VERSION="${HEAD_METADATA%%$'\t'*}"
HEAD_BUILD="${HEAD_METADATA##*$'\t'}"

[[ "${BASE_BUILD}" =~ ^[0-9]+$ ]] || fail "base の CURRENT_PROJECT_VERSION が整数ではありません: ${BASE_BUILD}"
[[ "${HEAD_BUILD}" =~ ^[0-9]+$ ]] || fail "head の CURRENT_PROJECT_VERSION が整数ではありません: ${HEAD_BUILD}"

expected_build=$((BASE_BUILD + 1))
if (( HEAD_BUILD != expected_build )); then
  fail "CURRENT_PROJECT_VERSION は main より 1 だけ大きい必要があります。main=${BASE_BUILD}, dev=${HEAD_BUILD}, expected=${expected_build}"
fi

transition_count=0
previous_metadata="${BASE_METADATA}"
transition_summary=()

while IFS= read -r commit; do
  commit_metadata="$(release_metadata "${commit}")"
  if [[ "${commit_metadata}" != "${previous_metadata}" ]]; then
    transition_count=$((transition_count + 1))
    transition_summary+=("${commit}: $(format_metadata "${previous_metadata}") -> $(format_metadata "${commit_metadata}")")
  fi
  previous_metadata="${commit_metadata}"
done < <(git rev-list --reverse "${BASE_SHA}..${HEAD_SHA}" -- "${PROJECT_FILE}")

if (( transition_count != 1 )); then
  echo "検出したリリース遷移数: ${transition_count}" >&2
  if (( ${#transition_summary[@]} > 0 )); then
    printf '  %s\n' "${transition_summary[@]}" >&2
  fi
  fail "main に存在しない dev のリリースは 1 つだけにしてください。"
fi

if [[ "${HEAD_METADATA}" == "${BASE_METADATA}" ]]; then
  fail "最終的なリリースバージョンが main と同一です。"
fi

release_tag="v${HEAD_VERSION}(${HEAD_BUILD})"

echo "Release branch policy OK"
echo "Base: $(format_metadata "${BASE_METADATA}") ${BASE_SHA}"
echo "Head: $(format_metadata "${HEAD_METADATA}") ${HEAD_SHA}"
echo "Release tag: ${release_tag}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=${HEAD_VERSION}"
    echo "build=${HEAD_BUILD}"
    echo "tag=${release_tag}"
    echo "base_sha=${BASE_SHA}"
    echo "head_sha=${HEAD_SHA}"
  } >> "${GITHUB_OUTPUT}"
fi
