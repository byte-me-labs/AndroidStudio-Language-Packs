#!/usr/bin/env bash
#
# Step 6 — Refresh the "最新版本" section of README.md from dist/metadata.json
# after a successful build, so the project doesn't look stale. Only the block
# between the LATEST markers is replaced; the rest of the README is untouched.
#
# Reads:   dist/metadata.json, README.md (override: META=<path> README=<path>)
# Writes:  README.md (in place)
#
# Called from the workflow after the Release is published. Gated on
# skip != 'true' so the idempotent-cron path (release already exists) doesn't
# rewrite the README.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

META="${META:-dist/metadata.json}"
README="${README:-README.md}"

[ -f "$META" ] || die "metadata missing ($META) — run build-packs.sh first"
grep -q '<!-- LATEST-BEGIN -->' "$README" || die "LATEST markers missing in $README"

repo="${GITHUB_REPOSITORY:-byte-me-labs/AndroidStudio-Language-Packs}"
as_ver="$(jq -r '.android_studio_version // empty' "$META")"
platform="$(jq -r '.platform_major // empty' "$META")"
tag="$(jq -r '.release_tag // empty' "$META")"
idea_ver="$(jq -r '.idea_source_version // empty' "$META")"
idea_build="$(jq -r '.idea_source_build // empty' "$META")"
build_date="$(date -u +%Y-%m-%d)"

block="构建日期 **$build_date**，适配 **Android Studio $as_ver**（IntelliJ 平台 $platform），语言包提取自 **IDEA Ultimate $idea_ver**（build $idea_build）。

| 版本 | 值 |
|---|---|
| Release | \`$tag\` |
| Android Studio | $as_ver |
| IntelliJ 平台 | $platform |
| IDEA 来源 | $idea_ver（build $idea_build） |
| 构建日期 | $build_date |

👉 [前往 Releases 下载最新语言包](https://github.com/$repo/releases/latest)"

# Replace only the block between the markers. ENVIRON avoids awk's own
# string-escaping rules for the multiline block.
export LATEST_BLOCK="$block"
awk '
  BEGIN { in_block = 0 }
  /<!-- LATEST-BEGIN -->/ { print; print ENVIRON["LATEST_BLOCK"]; in_block = 1; next }
  /<!-- LATEST-END -->/   { in_block = 0; next }
  !in_block               { print }
' "$README" > "$README.tmp"
mv "$README.tmp" "$README"

log "Updated $README (build $build_date, AS $as_ver, tag $tag)"
