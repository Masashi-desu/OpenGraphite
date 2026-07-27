#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/SampleProject/OpenGraphiteSample.ogp"

fail() {
  print -u2 -- "Tutorial synchronization validation failed: $1"
  exit 1
}

contains_exact_path() {
  local expected_path="$1"
  shift

  local candidate
  for candidate in "$@"; do
    if [[ "$candidate" == "$expected_path" ]]; then
      return 0
    fi
  done

  return 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required."
[[ -f "$PROJECT_FILE" ]] || fail "Sample project is missing: $PROJECT_FILE"

HTML_ROOT="$(jq -er '.htmlRoot | select(type == "string" and length > 0)' "$PROJECT_FILE")" \
  || fail "Sample project htmlRoot is missing."
PUBLIC_DIR="$ROOT_DIR/$HTML_ROOT"
[[ -d "$PUBLIC_DIR" ]] || fail "htmlRoot directory is missing: $PUBLIC_DIR"

PAGE_TUTORIAL_CONTAINER_COUNT="$(
  jq '[.chapters[]? | select(.id == "tutorials")] | length' "$PROJECT_FILE"
)"
[[ "$PAGE_TUTORIAL_CONTAINER_COUNT" == "1" ]] \
  || fail "Sample project must contain exactly one Tutorials Chapter."

COMPONENT_TUTORIAL_CONTAINER_COUNT="$(
  jq '[.collections[]? | select(.id == "tutorials")] | length' "$PROJECT_FILE"
)"
[[ "$COMPONENT_TUTORIAL_CONTAINER_COUNT" == "1" ]] \
  || fail "Sample project must contain exactly one Tutorials Collection."

PAGE_PATHS=("${(@f)$(
  jq -r '.chapters[] | select(.id == "tutorials") | .pages[]?.path' "$PROJECT_FILE"
)}")
COMPONENT_PATHS=("${(@f)$(
  jq -r '.collections[] | select(.id == "tutorials") | .components[]?.path' "$PROJECT_FILE"
)}")

(( ${#PAGE_PATHS[@]} > 0 )) || fail "Tutorials Chapter has no page lessons."
(( ${#COMPONENT_PATHS[@]} > 0 )) || fail "Tutorials Collection has no component lessons."

DUPLICATE_PAGE_PATH="$(
  jq -r '
    [.chapters[] | select(.id == "tutorials") | .pages[]?.path]
    | group_by(.)
    | map(select(length > 1) | .[0])
    | first // empty
  ' "$PROJECT_FILE"
)"
[[ -z "$DUPLICATE_PAGE_PATH" ]] \
  || fail "Tutorials Chapter registers a page path more than once: $DUPLICATE_PAGE_PATH"

DUPLICATE_COMPONENT_PATH="$(
  jq -r '
    [.collections[] | select(.id == "tutorials") | .components[]?.path]
    | group_by(.)
    | map(select(length > 1) | .[0])
    | first // empty
  ' "$PROJECT_FILE"
)"
[[ -z "$DUPLICATE_COMPONENT_PATH" ]] \
  || fail "Tutorials Collection registers a component path more than once: $DUPLICATE_COMPONENT_PATH"

for relative_path in "${PAGE_PATHS[@]}"; do
  [[ "$relative_path" == tutorial-*.html ]] \
    || fail "Tutorials Chapter path must match tutorial-*.html: $relative_path"

  html_path="$PUBLIC_DIR/$relative_path"
  css_path="${html_path%.html}.css"
  [[ -f "$html_path" ]] || fail "Registered page tutorial is missing: $relative_path"
  [[ -f "$css_path" ]] || fail "Page tutorial companion CSS is missing: ${relative_path%.html}.css"
done

for relative_path in "${COMPONENT_PATHS[@]}"; do
  [[ "$relative_path" == _components/tutorial-components-*.html ]] \
    || fail "Tutorials Collection path must match _components/tutorial-components-*.html: $relative_path"

  html_path="$PUBLIC_DIR/$relative_path"
  css_path="${html_path%.html}.css"
  [[ -f "$html_path" ]] || fail "Registered component tutorial is missing: $relative_path"
  [[ -f "$css_path" ]] || fail "Component tutorial companion CSS is missing: ${relative_path%.html}.css"
done

PAGE_HTML_FILES=("$PUBLIC_DIR"/tutorial-*.html(N))
PAGE_CSS_FILES=("$PUBLIC_DIR"/tutorial-*.css(N))
COMPONENT_HTML_FILES=("$PUBLIC_DIR"/_components/tutorial-components-*.html(N))
COMPONENT_CSS_FILES=("$PUBLIC_DIR"/_components/tutorial-components-*.css(N))

for html_path in "${PAGE_HTML_FILES[@]}"; do
  relative_path="${html_path#$PUBLIC_DIR/}"
  contains_exact_path "$relative_path" "${PAGE_PATHS[@]}" \
    || fail "Page tutorial source is not registered in the Tutorials Chapter: $relative_path"

  registration_count="$(
    jq --arg path "$relative_path" '[.chapters[]?.pages[]? | select(.path == $path)] | length' "$PROJECT_FILE"
  )"
  [[ "$registration_count" == "1" ]] \
    || fail "Page tutorial must have exactly one project placement: $relative_path"
done

for css_path in "${PAGE_CSS_FILES[@]}"; do
  [[ -f "${css_path%.css}.html" ]] \
    || fail "Page tutorial CSS has no same-named HTML: ${css_path#$PUBLIC_DIR/}"
done

for html_path in "${COMPONENT_HTML_FILES[@]}"; do
  relative_path="${html_path#$PUBLIC_DIR/}"
  contains_exact_path "$relative_path" "${COMPONENT_PATHS[@]}" \
    || fail "Component tutorial source is not registered in the Tutorials Collection: $relative_path"

  registration_count="$(
    jq --arg path "$relative_path" '[.collections[]?.components[]? | select(.path == $path)] | length' "$PROJECT_FILE"
  )"
  [[ "$registration_count" == "1" ]] \
    || fail "Component tutorial must have exactly one project placement: $relative_path"
done

for css_path in "${COMPONENT_CSS_FILES[@]}"; do
  [[ -f "${css_path%.css}.html" ]] \
    || fail "Component tutorial CSS has no same-named HTML: ${css_path#$PUBLIC_DIR/}"
done

print -- "Tutorial synchronization validation passed: ${#PAGE_PATHS[@]} page lessons, ${#COMPONENT_PATHS[@]} component lessons."
