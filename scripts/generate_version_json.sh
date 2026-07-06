#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# generate_version_json.sh
#
# Reads version info from pubspec.yaml + android/app/build.gradle + CHANGELOG.md
# and writes a validated version.json to the project root.
#
# Usage:
#   ./scripts/generate_version_json.sh
#   ./scripts/generate_version_json.sh --output /tmp/version.json
#
# Output file: version.json (or --output path)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
OUTPUT_FILE="$ROOT_DIR/version.json"

# Parse --output flag
while [[ $# -gt 0 ]]; do
  case $1 in
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

echo "=== OTYA Player — version.json generator ==="
echo "Root: $ROOT_DIR"

# ── 1. Read version from pubspec.yaml ────────────────────────────────────────
# pubspec.yaml format: version: 1.2.0+3
PUBSPEC="$ROOT_DIR/pubspec.yaml"
if [ ! -f "$PUBSPEC" ]; then
  echo "ERROR: pubspec.yaml not found at $PUBSPEC"
  exit 1
fi

VERSION_LINE=$(grep '^version:' "$PUBSPEC" | head -1)
VERSION_FULL=$(echo "$VERSION_LINE" | awk '{print $2}')   # e.g. 1.2.0+3
VERSION_NAME=$(echo "$VERSION_FULL" | cut -d'+' -f1)      # e.g. 1.2.0
VERSION_CODE=$(echo "$VERSION_FULL" | cut -d'+' -f2)      # e.g. 3

# If no build number in pubspec, derive from version name
if [ "$VERSION_CODE" = "$VERSION_NAME" ]; then
  VERSION_CODE=$(echo "$VERSION_NAME" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
fi

echo "Version name : $VERSION_NAME"
echo "Version code : $VERSION_CODE"

# ── 2. Read minSdk + targetSdk from android/app/build.gradle ─────────────────
BUILD_GRADLE="$ROOT_DIR/android/app/build.gradle"
if [ -f "$BUILD_GRADLE" ]; then
  MIN_SDK=$(grep 'minSdk' "$BUILD_GRADLE" | grep -v '//' | head -1 | grep -oP '\d+' || echo "21")
  TARGET_SDK=$(grep 'targetSdk' "$BUILD_GRADLE" | grep -v '//' | head -1 | grep -oP '\d+' || echo "36")
else
  echo "WARNING: android/app/build.gradle not found — using defaults."
  MIN_SDK=21
  TARGET_SDK=36
fi
echo "minSdk       : $MIN_SDK"
echo "targetSdk    : $TARGET_SDK"

# ── 3. Read changelog from CHANGELOG.md ──────────────────────────────────────
# Extracts the content of the first versioned section (## [x.y.z] ...)
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"
if [ -f "$CHANGELOG_FILE" ]; then
  CHANGELOG=$(awk '/^## \[/{found++} found==1{print} found==2{exit}' "$CHANGELOG_FILE" \
    | tail -n +2 \
    | grep -v '^[[:space:]]*$' \
    | head -40 \
    | tr '\n' ' ' \
    | sed 's/  */ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')
fi
if [ -z "${CHANGELOG:-}" ]; then
  CHANGELOG="Bug fixes and improvements"
fi
echo "Changelog    : ${CHANGELOG:0:80}..."

# ── 4. Get current UTC timestamp ─────────────────────────────────────────────
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Date         : $DATE"

# ── 5. Write version.json ─────────────────────────────────────────────────────
python3 - <<PYEOF
import json, sys

changelog = """$CHANGELOG""".strip()

data = {
    "version":     "$VERSION_NAME",
    "versionCode": int("$VERSION_CODE"),
    "date":        "$DATE",
    "arm64":       "app-arm64-v8a-standard-release.apk",
    "arm32":       "app-armeabi-v7a-standard-release.apk",
    "changelog":   changelog,
    "minSdk":      int("$MIN_SDK"),
    "targetSdk":   int("$TARGET_SDK"),
    "workerUrl":   "https://getotya.petersmartlink.com"
}

with open("$OUTPUT_FILE", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(json.dumps(data, indent=2))
PYEOF

# ── 6. Validate ───────────────────────────────────────────────────────────────
python3 -c "import json; d=json.load(open('$OUTPUT_FILE')); assert d['version'] and d['versionCode'] > 0"
echo ""
echo "✓ version.json written to $OUTPUT_FILE"
