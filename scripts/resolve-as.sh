#!/usr/bin/env bash
#
# Step 1 — Resolve the latest stable Android Studio and decide whether to build.
#
# Reads:   nothing
# Writes:  work/state.json (android_studio_version / _major, platform_major, release_tag, skipped)
#          dist/metadata.json  (only when skipping)
# Outputs: GITHUB_OUTPUT as_major / platform_major / skip
#
# Skip rules (idempotent cron): when SKIP_IF_EXISTS=1 and a GitHub Release
# v<AS-major> already exists, sets skipped=1 so later workflow steps are skipped.
# FORCE=1 bypasses the skip check.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

AS_UPDATES_XML="https://dl.google.com/android/studio/patches/updates.xml"
OUTDIR="dist"

log "Fetching Android Studio release channel: $AS_UPDATES_XML"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
curl -fsSL --retry 3 --retry-delay 5 "$AS_UPDATES_XML" -o "$WORKDIR/as.xml"

# First <build> under the first <channel status="release">.
rel_build="$(awk '/<channel[^>]*status="release"/{rel=1} rel && /<build /{print; exit}' "$WORKDIR/as.xml")"
[ -n "$rel_build" ] || die "No release-channel <build> found in $AS_UPDATES_XML"

platform_major="$(printf '%s' "$rel_build" | sed -n 's/.*apiVersion="AI-\([0-9][0-9]*\).*/\1/p')"
as_ver="$(printf '%s' "$rel_build" | sed -n 's/.*version="[^"]*| *\([0-9][0-9]*\(\.[0-9][0-9]*\)*\)[^"]*".*/\1/p')"
[ -n "$platform_major" ] && [ -n "$as_ver" ] || die "Could not parse Android Studio release info"
as_major="$(printf '%s' "$as_ver" | cut -d. -f1-2)"

# Cross-check with Google's documented scheme: (year % 100) * 10 + intellij-major
expected_major="$(( (10#${as_major%%.*} % 100) * 10 + 10#${as_major#*.} ))"
[ "$expected_major" -eq "$platform_major" ] || \
  warn "AS platform major $platform_major != schema $expected_major for $as_major; trusting updates.xml"

log "Latest stable Android Studio: $as_ver (major $as_major, platform $platform_major)"
tag="v$as_major"

# --- skip if a Release for this AS major already exists (idempotent cron) ---
skip=0
if [ "${FORCE:-0}" != "1" ] && [ "${SKIP_IF_EXISTS:-0}" = "1" ] \
   && [ -n "${GITHUB_REPOSITORY:-}" ] && command -v gh >/dev/null 2>&1; then
  if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
    log "Release $tag already exists for AS $as_major; skipping (set FORCE=1 to rebuild)."
    skip=1
  fi
fi

# --- persist state + step outputs ---
state_set android_studio_version "$as_ver"
state_set android_studio_major "$as_major"
state_set platform_major "$platform_major"
state_set release_tag "$tag"
state_set skipped "$skip"
if [ "$skip" = "1" ]; then
  state_set skip_reason "release already exists"
  mkdir -p "$OUTDIR"
  cat > "$OUTDIR/metadata.json" <<EOF
{
  "skipped": true,
  "android_studio_major": "$as_major",
  "platform_major": "$platform_major",
  "release_tag": "$tag",
  "reason": "release already exists"
}
EOF
fi

gh_output as_major "$as_major"
gh_output platform_major "$platform_major"
gh_output skip "$([ "$skip" = "1" ] && echo true || echo false)"

log "skipped=$skip"
