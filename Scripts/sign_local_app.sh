#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <app-bundle>" >&2
  exit 2
fi

APP_BUNDLE="$1"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: app bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

select_signing_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  local identity
  identity="$(printf '%s\n' "$identities" | awk -F '"' '/"Apple Development:/{ print $2; exit }')"
  if [[ -n "$identity" ]]; then
    printf '%s\n' "$identity"
    return
  fi

  identity="$(printf '%s\n' "$identities" | awk -F '"' '/"Developer ID Application:/{ print $2; exit }')"
  if [[ -n "$identity" ]]; then
    printf '%s\n' "$identity"
    return
  fi

  printf '%s\n' "-"
}

SIGNING_IDENTITY="$(select_signing_identity)"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "==> codesign local app with ad hoc identity"
  echo "warning: no Apple-issued codesigning identity found; AppIntents registration may still be rejected by macOS" >&2
else
  echo "==> codesign local app with Apple-issued identity"
fi

codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
