#!/usr/bin/env bash
#
# Shared helpers for the pipeline scripts. Source this file, don't execute it:
#   source "$(dirname "$0")/lib/common.sh"
#
# State: each step script reads/writes one JSON file (default work/state.json)
# so values discovered by earlier steps (AS version, platform major, IDEA URL …)
# flow to later steps without re-fetching. Override via STATE=<path>.

set -euo pipefail

STATE="${STATE:-work/state.json}"

command -v jq >/dev/null 2>&1 || { echo "[common][error] jq is required" >&2; exit 1; }

log()  { printf '[%s] %s\n' "$(basename "${BASH_SOURCE[1]:-sh}")" "$*"; }
warn() { printf '[%s][warn] %s\n' "$(basename "${BASH_SOURCE[1]:-sh}")" "$*" >&2; }
die()  { printf '[%s][error] %s\n' "$(basename "${BASH_SOURCE[1]:-sh}")" "$*" >&2; exit 1; }

# Read a string key from the state file; empty string when missing.
state_get() { [ -f "$STATE" ] || return 1; jq -r --arg k "$1" '.[$k] // empty' "$STATE"; }

# Write a string key into the state file (creates it on first use).
state_set() {
  mkdir -p "$(dirname "$STATE")"
  if [ -f "$STATE" ]; then
    jq --arg k "$1" --arg v "$2" '.[$k] = $v' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  else
    printf '{"%s":"%s"}\n' "$1" "$2" > "$STATE"
  fi
}

# Echo a GitHub Actions step output; no-op when running locally.
gh_output() { [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT" || true; }
