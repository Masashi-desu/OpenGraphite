#!/usr/bin/env zsh

set -euo pipefail

exec "$(dirname "$0")/quality_gate.sh"
