#!/usr/bin/env bash
# scripts/publish_r2.sh
# Called by GitLab CI publish_to_r2 job after build_release.
# All secrets come from CI environment variables.
#
# Required env vars:
#   CI_COMMIT_TAG          e.g. v1.3.3
#   R2_ENDPOINT            Cloudflare R2 S3-compatible endpoint
#   R2_BUCKET              R2 bucket name
#   WORKER_URL             https://getotya.petersmartlink.com
#   AWS_ACCESS_KEY_ID      R2 access key (set by CI job variables)
#   AWS_SECRET_ACCESS_KEY  R2 secret key (set by CI job variables)
# Optional:
#   APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_API_KEY
#   CF_ACCOUNT_ID, CF_API_TOKEN  (for KV cache purge after upload)

set -euo pipefail

# ── Resolve version ────────────────────────────────────────────────────────────
VERSION=${CI_COMMIT_TAG#v}
# Use pubspec versionCode (the +N part) if available, else derive from semver
PUBSPEC_CODE=$(grep '^version:' pubspec.yaml | head -1 | grep -oP '(?<=\+)\d+' || echo "")
if [ -n "$PUBSPEC_CODE" ]; then
  VERSION_CODE="$PUBSPEC_CODE"
else
  VERSION_CODE=$(echo "$VERSION" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
fi
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "=== Publishing OTYA Player v$VERSION (versionCode=$VERSION_CODE) ==="

# ── Verify APK artifacts exist before doing anything ──────────────────────────
ARM64_APK="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
ARM32_APK="build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"

for APK in "$ARM64_APK" "$ARM32_APK"; do
  if [ ! -f "$APK" ]; then
    echo "ERROR: APK not found: $APK"
    echo "Contents of flutter-apk dir:"
    ls -lh build/app/outputs/flutter-apk/ 2>/dev/null || echo "(directory missing)"
    exit 1
  fi
  SIZE=$(stat -c%s "$APK" 2>/dev/null || stat -f%z "$APK")
  if [ "$SIZE" -lt 5000000 ]; then
    echo "ERROR: $APK looks too small ($SIZE bytes) — build may have failed"
    exit 1
  fi
  echo "OK: $APK ($SIZE bytes)"
done

# ── Read changelog safely (write to temp file to avoid heredoc injection) ─────
CHANGELOG_FILE=$(mktemp)
trap 'rm -f "$CHANGELOG_FILE"' EXIT

awk '/^## \[/{found++} found==1{print} found==2{exit}' CHANGELOG.md \
  | tail -n +2 | head -40 \
  | tr '\n' ' ' \
  | sed 's/  */ /g; s/^[[:space:]]*//; s/[[:space:]]*$//' \
  > "$CHANGELOG_FILE"

CHANGELOG=$(cat "$CHANGELOG_FILE")
[ -z "$CHANGELOG" ] && CHANGELOG="Bug fixes and improvements"
echo "Changelog: ${CHANGELOG:0:80}..."

# ── Read SDK versions from build.gradle ───────────────────────────────────────
MIN_SDK=$(grep 'minSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 21)
TARGET_SDK=$(grep 'targetSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 36)
echo "minSdk=$MIN_SDK  targetSdk=$TARGET_SDK"

# ── Backup current version before overwriting ─────────────────────────────────
CURRENT_VERSION=$(aws s3 cp \
  "s3://${R2_BUCKET}/version.json" - \
  --endpoint-url "$R2_ENDPOINT" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version',''))" 2>/dev/null \
  || echo "")

if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "$VERSION" ]; then
  echo "Backing up v$CURRENT_VERSION to releases/v$CURRENT_VERSION/..."
  for KEY in app-arm64-v8a-release.apk app-armeabi-v7a-release.apk version.json; do
    aws s3 cp \
      "s3://${R2_BUCKET}/${KEY}" \
      "s3://${R2_BUCKET}/releases/v${CURRENT_VERSION}/${KEY}" \
      --endpoint-url "$R2_ENDPOINT" 2>/dev/null || true
  done
  echo "Backup complete."
fi

# ── Upload APKs ────────────────────────────────────────────────────────────────
upload_and_verify() {
  local SRC="$1"
  local DEST_KEY="$2"
  local LOCAL_SIZE
  LOCAL_SIZE=$(stat -c%s "$SRC" 2>/dev/null || stat -f%z "$SRC")

  echo "Uploading $DEST_KEY ($LOCAL_SIZE bytes)..."
  aws s3 cp \
    "$SRC" \
    "s3://${R2_BUCKET}/${DEST_KEY}" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type application/vnd.android.package-archive \
    --cache-control "public, max-age=31536000, immutable"

  # Verify upload size matches local file
  REMOTE_SIZE=$(aws s3 ls \
    "s3://${R2_BUCKET}/${DEST_KEY}" \
    --endpoint-url "$R2_ENDPOINT" \
    | awk '{print $3}')

  if [ "$REMOTE_SIZE" != "$LOCAL_SIZE" ]; then
    echo "ERROR: Upload size mismatch for $DEST_KEY"
    echo "  Local:  $LOCAL_SIZE bytes"
    echo "  Remote: $REMOTE_SIZE bytes"
    exit 1
  fi
  echo "OK: $DEST_KEY verified ($REMOTE_SIZE bytes)"
}

upload_and_verify "$ARM64_APK" "app-arm64-v8a-release.apk"
upload_and_verify "$ARM32_APK" "app-armeabi-v7a-release.apk"

# ── Generate version.json ──────────────────────────────────────────────────────
# Write changelog to a temp file so Python reads it safely (no shell injection)
python3 - "$VERSION" "$VERSION_CODE" "$DATE" "$MIN_SDK" "$TARGET_SDK" "$WORKER_URL" "$CHANGELOG_FILE" <<'PYEOF'
import json, sys

version, version_code, date, min_sdk, target_sdk, worker_url, changelog_file = sys.argv[1:]

with open(changelog_file) as f:
    changelog = f.read().strip()

data = {
    "version":     version,
    "versionCode": int(version_code),
    "date":        date,
    "arm64":       "app-arm64-v8a-release.apk",
    "arm32":       "app-armeabi-v7a-release.apk",
    "changelog":   changelog or "Bug fixes and improvements",
    "minSdk":      int(min_sdk),
    "targetSdk":   int(target_sdk),
    "workerUrl":   worker_url,
    "downloads": {
        "arm64": f"{worker_url}/apk/arm64",
        "arm32": f"{worker_url}/apk/arm32",
        "auto":  f"{worker_url}/download",
    },
}

with open("version.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(json.dumps(data, indent=2))
PYEOF

# Validate JSON before uploading
python3 -c "import json; json.load(open('version.json'))" \
  || { echo "ERROR: version.json is not valid JSON — aborting"; exit 1; }

# ── Upload version.json LAST (Worker reads this to find APK keys) ─────────────
echo "Uploading version.json..."
aws s3 cp \
  version.json \
  "s3://${R2_BUCKET}/version.json" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type application/json \
  --cache-control "public, max-age=300"
echo "OK: version.json uploaded"

# ── Purge Worker KV cache so new version is live immediately ──────────────────
# Without this, the Worker serves the old version for up to 10 minutes.
if [ -n "${CF_ACCOUNT_ID:-}" ] && [ -n "${CF_API_TOKEN:-}" ] && [ -n "${KV_NAMESPACE_ID:-}" ]; then
  echo "Purging KV cache key 'version:current'..."
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/version:current" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json")
  if [ "$HTTP" = "200" ] || [ "$HTTP" = "404" ]; then
    echo "OK: KV cache purged (HTTP $HTTP) — new version live immediately"
  else
    echo "WARN: KV purge returned HTTP $HTTP — new version will be live within 10 min"
  fi
else
  echo "INFO: CF_ACCOUNT_ID/CF_API_TOKEN/KV_NAMESPACE_ID not set — KV cache will expire naturally (~10 min)"
fi

# ── Notify Appwrite (in-app update checker) ───────────────────────────────────
if [ -n "${APPWRITE_ENDPOINT:-}" ] && [ -n "${APPWRITE_PROJECT_ID:-}" ] && [ -n "${APPWRITE_API_KEY:-}" ]; then
  echo "Notifying Appwrite..."
  DOC_ID=$(echo "v${VERSION}" | tr '.' '-')
  DOC_BODY=$(python3 - "$VERSION" "$VERSION_CODE" "$DATE" "$WORKER_URL" "$MIN_SDK" "$TARGET_SDK" "$CHANGELOG_FILE" <<'PYEOF'
import json, sys
version, version_code, date, worker_url, min_sdk, target_sdk, changelog_file = sys.argv[1:]
with open(changelog_file) as f:
    changelog = f.read().strip()
print(json.dumps({
    "documentId": f"v{version.replace('.', '-')}",
    "data": {
        "version":     version,
        "versionCode": int(version_code),
        "date":        date,
        "changelog":   changelog or "Bug fixes and improvements",
        "arm64Url":    f"{worker_url}/apk/arm64",
        "arm32Url":    f"{worker_url}/apk/arm32",
        "downloadUrl": f"{worker_url}/download",
        "minSdk":      int(min_sdk),
        "targetSdk":   int(target_sdk),
    },
}))
PYEOF
)
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    "${APPWRITE_ENDPOINT}/databases/otya-db/collections/releases/documents" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: ${APPWRITE_PROJECT_ID}" \
    -H "X-Appwrite-Key: ${APPWRITE_API_KEY}" \
    -d "$DOC_BODY")
  if [ "$HTTP_STATUS" = "201" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo "OK: Appwrite notified (HTTP $HTTP_STATUS)"
  else
    echo "WARN: Appwrite returned HTTP $HTTP_STATUS — in-app update checker may be delayed"
  fi
else
  echo "INFO: Appwrite vars not set — skipping notification"
fi

# ── Prune old backups (keep last 5) ───────────────────────────────────────────
echo "Pruning old backups (keeping last 5)..."
VERSIONS=$(aws s3 ls "s3://${R2_BUCKET}/releases/" \
  --endpoint-url "$R2_ENDPOINT" 2>/dev/null \
  | awk '{print $2}' | sort -V | head -n -5)
for OLD in $VERSIONS; do
  echo "Deleting old backup: $OLD"
  aws s3 rm "s3://${R2_BUCKET}/releases/${OLD}" \
    --endpoint-url "$R2_ENDPOINT" --recursive 2>/dev/null || true
done

echo ""
echo "====================================================="
echo " OTYA Player v$VERSION published successfully!"
echo " Live at: ${WORKER_URL}/download"
echo " Version JSON: ${WORKER_URL}/version"
echo "====================================================="
