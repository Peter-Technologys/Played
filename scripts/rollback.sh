#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# rollback.sh — Roll back OTYA Player R2 release to a previous version
#
# Usage:
#   ./scripts/rollback.sh <version>
#   ./scripts/rollback.sh 1.2.2
#
# What it does:
#   1. Copies APKs from releases/v<version>/ back to the R2 root
#   2. Regenerates version.json for that version
#   3. Uploads version.json LAST (so Worker is always consistent)
#
# Required environment variables (or set in your shell):
#   R2_ACCESS_KEY_ID
#   R2_SECRET_ACCESS_KEY
#   R2_ENDPOINT   (default: https://6c76d2a9e5f95d5f9b393e97374d9afb.r2.cloudflarestorage.com)
#   R2_BUCKET     (default: otya-player-releases)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>   e.g. $0 1.2.2"
  exit 1
fi

# Strip leading 'v' if provided
VERSION=${VERSION#v}

R2_ENDPOINT="${R2_ENDPOINT:-https://6c76d2a9e5f95d5f9b393e97374d9afb.r2.cloudflarestorage.com}"
R2_BUCKET="${R2_BUCKET:-otya-player-releases}"
WORKER_URL="https://getotya.petersmartlink.com"

export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID is required}"
export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY is required}"
export AWS_DEFAULT_REGION=auto

echo "=== OTYA Player Rollback ==="
echo "Rolling back to v$VERSION from R2 archive..."
echo ""

# ── 1. Check the archive exists ───────────────────────────────────────────────
ARCHIVE_PREFIX="releases/v$VERSION/"
FILE_COUNT=$(aws s3 ls "s3://$R2_BUCKET/$ARCHIVE_PREFIX" \
  --endpoint-url "$R2_ENDPOINT" 2>/dev/null | wc -l || echo 0)

if [ "$FILE_COUNT" -eq 0 ]; then
  echo "ERROR: No archived files found at s3://$R2_BUCKET/$ARCHIVE_PREFIX"
  echo ""
  echo "Available backups:"
  aws s3 ls "s3://$R2_BUCKET/releases/" --endpoint-url "$R2_ENDPOINT" 2>/dev/null || echo "  (none)"
  exit 1
fi

echo "Found $FILE_COUNT file(s) in archive. Proceeding..."
echo ""

# ── 2. Copy APKs from archive to root ────────────────────────────────────────
for KEY in app-arm64-v8a-standard-release.apk app-armeabi-v7a-standard-release.apk; do
  echo "Restoring $KEY..."
  aws s3 cp \
    "s3://$R2_BUCKET/releases/v$VERSION/$KEY" \
    "s3://$R2_BUCKET/$KEY" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type application/vnd.android.package-archive \
    --cache-control "public, max-age=31536000, immutable"
done

# ── 3. Restore or regenerate version.json ────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf $TMP_DIR' EXIT

# Try to restore the archived version.json first
if aws s3 cp \
  "s3://$R2_BUCKET/releases/v$VERSION/version.json" \
  "$TMP_DIR/version.json" \
  --endpoint-url "$R2_ENDPOINT" 2>/dev/null; then
  echo "Restored archived version.json for v$VERSION."
else
  echo "No archived version.json found — regenerating..."
  VERSION_CODE=$(echo "$VERSION" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
  DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  python3 - <<PYEOF
import json
data = {
    "version":     "$VERSION",
    "versionCode": int("$VERSION_CODE"),
    "date":        "$DATE",
    "arm64":       "app-arm64-v8a-standard-release.apk",
    "arm32":       "app-armeabi-v7a-standard-release.apk",
    "changelog":   "Rolled back to v$VERSION",
    "minSdk":      21,
    "targetSdk":   36,
    "workerUrl":   "$WORKER_URL"
}
with open("$TMP_DIR/version.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(json.dumps(data, indent=2))
PYEOF
fi

# Validate
python3 -c "import json; json.load(open('$TMP_DIR/version.json'))" || { echo "ERROR: Invalid version.json"; exit 1; }

# ── 4. Upload version.json LAST ───────────────────────────────────────────────
echo "Uploading version.json..."
aws s3 cp \
  "$TMP_DIR/version.json" \
  "s3://$R2_BUCKET/version.json" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type application/json \
  --cache-control "public, max-age=300"

echo ""
echo "✓ Rollback to v$VERSION complete."
echo "  Worker URL : $WORKER_URL"
echo "  Version    : $(python3 -c "import json; d=json.load(open('$TMP_DIR/version.json')); print(d['version'])")"
