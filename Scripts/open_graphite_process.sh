#!/usr/bin/env bash

OG_APP_NAME="${OG_APP_NAME:-OpenGraphite}"
OG_BUNDLE_ID="${OG_BUNDLE_ID:-dev.opengraphite.OpenGraphite}"

open_graphite_pids() {
  pgrep -x "$OG_APP_NAME" || true
}

open_graphite_process_count() {
  open_graphite_pids | wc -l | tr -d '[:space:]'
}

stop_running_open_graphite() {
  local attempts

  if [[ "$(open_graphite_process_count)" == "0" ]]; then
    return 0
  fi

  /usr/bin/osascript -e "tell application id \"$OG_BUNDLE_ID\" to quit" >/dev/null 2>&1 || true

  attempts=0
  while [[ "$(open_graphite_process_count)" != "0" && "$attempts" -lt 25 ]]; do
    sleep 0.2
    attempts=$((attempts + 1))
  done

  if [[ "$(open_graphite_process_count)" == "0" ]]; then
    return 0
  fi

  pkill -TERM -x "$OG_APP_NAME" >/dev/null 2>&1 || true

  attempts=0
  while [[ "$(open_graphite_process_count)" != "0" && "$attempts" -lt 25 ]]; do
    sleep 0.2
    attempts=$((attempts + 1))
  done

  if [[ "$(open_graphite_process_count)" != "0" ]]; then
    echo "error: $OG_APP_NAME is still running after termination request" >&2
    open_graphite_pids >&2
    return 1
  fi
}

wait_for_single_open_graphite() {
  local attempts

  attempts=0
  while [[ "$attempts" -lt 25 ]]; do
    if [[ "$(open_graphite_process_count)" == "1" ]]; then
      return 0
    fi

    sleep 0.2
    attempts=$((attempts + 1))
  done

  echo "error: expected exactly one $OG_APP_NAME process after launch" >&2
  open_graphite_pids >&2
  return 1
}
