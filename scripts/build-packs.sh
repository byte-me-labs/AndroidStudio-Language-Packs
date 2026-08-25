#!/usr/bin/env bash
#
# Step 4 — Rewrite each jar's META-INF/plugin.xml for the target platform and
# package the three installable plugin zips.
#
# Reads:   work/state.json (platform_major, idea_version / _build,
#                          android_studio_version / _major, release_tag, idea_fallback)
#          work/idea/plugins/localization-*/lib/*.jar
# Writes:  dist/localization-{zh,ja,ko}-<platform>.zip
#          dist/metadata.json, dist/release-notes.md
#
# Rewrite: <idea-version since-build="AI-0" until-build="AI-999.*" />
# Android Studio requires the AI- build prefix for plugin compatibility.

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

LANG_CODES=(zh ja ko)
OUTDIR="dist"
SRC_ROOT="work/idea/plugins"

# Read state first (dist/ is recreated below, but state lives in work/).
platform_major="$(state_get platform_major)"
as_ver="$(state_get android_studio_version)"
as_major="$(state_get android_studio_major)"
idea_version="$(state_get idea_version)"
idea_build="$(state_get idea_build)"
tag="$(state_get release_tag)"
fallback="$(state_get idea_fallback)"; fallback="${fallback:-0}"
[ -n "$platform_major" ] || die "platform_major missing from state (run resolve-as.sh first)"
[ -n "$idea_version" ]  || die "idea_version missing from state (run resolve-idea.sh first)"

[ -d "$SRC_ROOT" ] || die "work/idea/plugins missing (run extract-jars.sh first)"
SRC_ROOT_ABS="$(cd "$SRC_ROOT" && pwd)"   # absolute — used inside a cd'd subshell below

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

rm -rf "$OUTDIR"; mkdir -p "$OUTDIR"
OUTDIR_ABS="$(cd "$OUTDIR" && pwd)"

for lang in "${LANG_CODES[@]}"; do
  src_jar="$SRC_ROOT_ABS/localization-$lang/lib/localization-$lang.jar"
  [ -f "$src_jar" ] || die "localization-$lang.jar missing (run extract-jars.sh first)"

  # Rewrite the single plugin.xml entry for Android Studio (idea-version must use
  # the AI- build prefix), then rebuild the jar with unzip+zip instead of `zip -u`
  # in place: JetBrains jars carry a build-time `__index__` resource index tied to
  # the original byte layout, and any archive change makes it point past EOF,
  # which IntelliJ's strict ImmutableZipFile reader rejects. Dropping `__index__`
  # makes the loader fall back to the central directory.
  rbd="$WORKDIR/rebuild/$lang"
  rm -rf "$rbd"; mkdir -p "$rbd"
  ( cd "$rbd" && unzip -q "$src_jar" )
  rm -f "$rbd/__index__"
  grep -q "<id>com.intellij.$lang</id>" "$rbd/META-INF/plugin.xml" \
    || die "unexpected plugin id in localization-$lang.jar"
  sed -i -E 's|<idea-version[^>]*/>|<idea-version since-build="AI-0" until-build="AI-999.*" />|' \
    "$rbd/META-INF/plugin.xml"
  grep -q 'since-build="AI-0"' "$rbd/META-INF/plugin.xml" \
    || die "plugin.xml rewrite failed for $lang"

  # Installable plugin zip: mirror the official JetBrains language-pack layout — a
  # single top-level plugin directory (zh/ja/ko) holding lib/localization-<lang>.jar,
  # with the descriptor inside the jar. A flat lib/ at the zip root is not loadable.
  pkg_dir="$WORKDIR/pkg/$lang"
  mkdir -p "$pkg_dir/lib"
  ( cd "$rbd" && zip -q -r "$pkg_dir/lib/localization-$lang.jar" * )
  # Self-check the rebuilt jar: no `__index__` (would break IntelliJ's strict
  # reader) and the AI- rewrite survived the rebuild.
  unzip -l "$pkg_dir/lib/localization-$lang.jar" | grep -q '__index__' \
    && die "rebuilt localization-$lang.jar still contains __index__"
  unzip -p "$pkg_dir/lib/localization-$lang.jar" META-INF/plugin.xml | grep -q 'since-build="AI-0"' \
    || die "rebuilt localization-$lang.jar lost the idea-version rewrite"
  ( cd "$WORKDIR/pkg" && zip -q -r "$OUTDIR_ABS/localization-$lang-$platform_major.zip" "$lang" )
  log "Built $OUTDIR/localization-$lang-$platform_major.zip"
done

cat > "$OUTDIR_ABS/metadata.json" <<EOF
{
  "android_studio_version": "$as_ver",
  "android_studio_major": "$as_major",
  "platform_major": "$platform_major",
  "idea_source_version": "$idea_version",
  "idea_source_build": "$idea_build",
  "release_tag": "$tag",
  "idea_major_mismatch_fallback": $fallback,
  "artifacts": [
    "localization-zh-$platform_major.zip",
    "localization-ja-$platform_major.zip",
    "localization-ko-$platform_major.zip"
  ]
}
EOF

cat > "$OUTDIR_ABS/release-notes.md" <<EOF
# Android Studio 语言包 v$as_major（platform $platform_major）

适配 **Android Studio $as_ver**（大版本 $as_major，IntelliJ 平台 $platform_major）。

## 语言包来源

| 项目 | 值 |
|---|---|
| 来源发行版 | IntelliJ IDEA Ultimate |
| IDEA 版本 | $idea_version（build $idea_build） |
| 提取内容 | \`plugins/localization-{zh,ja,ko}/lib/localization-<lang>.jar\` |
| 版本改写 | \`<idea-version since-build="AI-0" until-build="AI-999.*" />\`（Android Studio 兼容所需的 AI- 前缀） |

## 安装

\`Settings → Plugins → ⚙️ → Install Plugin from Disk…\` → 选择对应 zip → 重启后到 \`Settings → Appearance & Behavior → System Settings → Language and Region\` 切换语言。

## 许可

语言包提取自 IntelliJ IDEA Ultimate（JetBrains 商业软件）发行版内置的 \`plugins/localization-*\`；翻译文本版权归 JetBrains，未经明示授权再分发，仅供个人使用，使用风险自担。
EOF

log "Wrote $OUTDIR/metadata.json and $OUTDIR/release-notes.md"
