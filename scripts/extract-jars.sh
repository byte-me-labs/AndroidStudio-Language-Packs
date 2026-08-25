#!/usr/bin/env bash
#
# Step 3 — Download the IDEA distribution zip (unless cached) and partial-unzip
# the three localization jars.
#
# Reads:   work/state.json (idea_zip_url, idea_version)
# Writes:  work/idea.zip (download), work/idea/plugins/localization-*/lib/*.jar
#
# An existing non-empty work/idea.zip (e.g. from a previous local run) skips
# the download. Only the three jars are pulled out of the ~1.5 GB archive.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

IDEA_ZIP="${IDEA_ZIP:-work/idea.zip}"
EXTRACT_DIR="${EXTRACT_DIR:-work/idea}"
LANG_CODES=(zh ja ko)

idea_zip_url="$(state_get idea_zip_url)"
idea_version="$(state_get idea_version)"
[ -n "$idea_zip_url" ] || die "idea_zip_url missing from state (run resolve-idea.sh first)"

if [ -s "$IDEA_ZIP" ]; then
  log "Found existing IDEA zip at $IDEA_ZIP; skipping download"
else
  log "Downloading IDEA $idea_version windows zip (about 1.5 GB)..."
  mkdir -p "$(dirname "$IDEA_ZIP")"
  curl -fL --retry 3 --retry-delay 5 -C - -o "$IDEA_ZIP" "$idea_zip_url"
fi

mkdir -p "$EXTRACT_DIR"
for lang in "${LANG_CODES[@]}"; do
  unzip -o -q "$IDEA_ZIP" "plugins/localization-$lang/lib/*" -d "$EXTRACT_DIR" || true
  [ -f "$EXTRACT_DIR/plugins/localization-$lang/lib/localization-$lang.jar" ] \
    || die "localization-$lang.jar not found in the IDEA package (layout changed?)"
done
log "Extracted zh / ja / ko localization jars"
