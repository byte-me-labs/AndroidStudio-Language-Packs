#!/usr/bin/env bash
#
# Step 2 — Find the IDEA Ultimate stable release matching the AS major version.
#
# Reads:   work/state.json (android_studio_major)
# Writes:  work/state.json (idea_version / _build / _zip_url, idea_fallback)
# Outputs: GITHUB_OUTPUT idea_version
#
# Matching: prefer a release whose majorVersion equals the AS calendar major
# (AS 2026.1 ↔ IDEA 2026.1); fall back to the latest stable IDEA when none matches.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

IDEA_API="https://data.services.jetbrains.com/products/releases"
CODE="IIU"   # IntelliJ IDEA Ultimate

as_major="$(state_get android_studio_major)"
[ -n "$as_major" ] || die "android_studio_major missing from state (run resolve-as.sh first)"

log "Looking up IDEA Ultimate stable matching major $as_major"
idea_json="$(curl -fsSL --retry 3 --retry-delay 5 "$IDEA_API?code=$CODE&type=release&majorVersion=$as_major")"
matched="$(printf '%s' "$idea_json" | jq -c --arg c "$CODE" --arg m "$as_major" \
  '[.[$c][] | select(.majorVersion==$m)] | sort_by(.date) | reverse | .[0] // empty')"

if [ -z "$matched" ]; then
  warn "majorVersion filter returned nothing for $as_major; re-scanning the full release list"
  idea_json="$(curl -fsSL --retry 3 --retry-delay 5 "$IDEA_API?code=$CODE&type=release")"
  matched="$(printf '%s' "$idea_json" | jq -c --arg c "$CODE" --arg m "$as_major" \
    '[.[$c][] | select(.majorVersion==$m)] | sort_by(.date) | reverse | .[0] // empty')"
fi

fallback=0
if [ -z "$matched" ]; then
  warn "No IDEA Ultimate release for AS major $as_major; falling back to the latest stable IDEA"
  idea_json="$(curl -fsSL --retry 3 --retry-delay 5 "$IDEA_API?code=$CODE&latest=true&type=release")"
  matched="$(printf '%s' "$idea_json" | jq -c --arg c "$CODE" '.[$c][0]')"
  fallback=1
fi
[ -n "$matched" ] && [ "$matched" != "null" ] || die "Could not resolve any IDEA Ultimate release"

idea_version="$(printf '%s' "$matched" | jq -r '.version')"
idea_build="$(printf '%s' "$matched" | jq -r '.build')"
idea_zip_url="$(printf '%s' "$matched" | jq -r '.downloads.windowsZip.link')"
[ -n "$idea_zip_url" ] && [ "$idea_zip_url" != "null" ] || die "IDEA $idea_version has no windowsZip download"
log "Matched IDEA Ultimate $idea_version (build $idea_build)"

state_set idea_version "$idea_version"
state_set idea_build "$idea_build"
state_set idea_zip_url "$idea_zip_url"
state_set idea_fallback "$fallback"
gh_output idea_version "$idea_version"
