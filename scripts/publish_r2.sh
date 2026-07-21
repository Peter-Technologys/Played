#!/usr/bin/env bash
# scripts/publish_r2.sh
# Called by both GitLab CI (publish_to_r2) and GitHub Actions (Publish to Cloudflare R2).
# All secrets/vars come from environment variables set by the CI system.
#
# Required env vars:
#   For GitLab CI:  CI_COMMIT_TAG (e.g. v1.3.3)
#   For GitHub:     GITHUB_REF_NAME (e.g. v1.3.3)
#   R2_ENDPOINT, R2_BUCKET, WORKER_URL
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
# Optional:
#   APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_API_KEY
#   CF_ACCOUNT_ID, CF_API_TOKEN, KV_NAMESPACE_ID

set -euo pipefail

# ── Resolve tag (works in both GitLab CI and GitHub Actions) ─────────────────
RAW_TAG="${CI_COMMIT_TAG:-${GITHUB_REF_NAME:-}}"
if [ -z "$RAW_TAG" ]; then
  echo "ERROR: No tag found. Set CI_COMMIT_TAG or GITHUB_REF_NAME."
  exit 1
fi
VERSION="${RAW_TAG#v}"

# Use pubspec versionCode (+N) if available, else derive from semver
PUBSPEC_CODE=$(grep '^version:' pubspec.yaml | head -1 | grep -oP '(?<=\+)\d+' || echo "")
if [ -n "$PUBSPEC_CODE" ]; then
  VERSION_CODE="$PUBSPEC_CODE"
else
  VERSION_CODE=$(echo "$VERSION" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
fi
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "=== Publishing OTYA Player v$VERSION (versionCode=$VERSION_CODE) ==="

# ── Verify APK artifacts exist ─────────────────────────────────────────────────
ARM64_APK="${ARM64_APK:-build/app/outputs/flutter-apk/app-arm64-v8a-release.apk}"
ARM32_APK="${ARM32_APK:-build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk}"

for APK in "$ARM64_APK" "$ARM32_APK"; do
  if [ ! -f "$APK" ]; then
    echo "ERROR: APK not found: $APK"
    ls -lh build/app/outputs/flutter-apk/ 2>/dev/null || echo "(directory missing)"
    exit 1
  fi
  SIZE=$(stat -c%s "$APK" 2>/dev/null || stat -f%z "$APK")
  if [ "$SIZE" -lt 5000000 ]; then
    echo "ERROR: $APK looks too small ($SIZE bytes)"
    exit 1
  fi
  echo "OK: $APK ($SIZE bytes)"
done

# ── Read changelog safely ─────────────────────────────────────────────────────────
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

# ── Read SDK versions ───────────────────────────────────────────────────────────────
MIN_SDK=$(grep 'minSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 21)
TARGET_SDK=$(grep 'targetSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 36)
echo "minSdk=$MIN_SDK  targetSdk=$TARGET_SDK"

# ── Backup current version ───────────────────────────────────────────────────────────
CURRENT_VERSION=$(aws s3 cp \
  "s3://${R2_BUCKET}/version.json" - \
  --endpoint-url "$R2_ENDPOINT" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version',''))" 2>/dev/null \
  || echo "")

if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "$VERSION" ]; then
  echo "Backing up v$CURRENT_VERSION..."
  for KEY in OtyaPlayer-arm64.apk OtyaPlayer-arm32.apk version.json; do
    aws s3 cp \
      "s3://${R2_BUCKET}/${KEY}" \
      "s3://${R2_BUCKET}/releases/v${CURRENT_VERSION}/${KEY}" \
      --endpoint-url "$R2_ENDPOINT" 2>/dev/null || true
  done
fi

# ── Upload APKs with verification ─────────────────────────────────────────────────
upload_and_verify() {
  local SRC="$1" DEST_KEY="$2"
  local LOCAL_SIZE
  LOCAL_SIZE=$(stat -c%s "$SRC" 2>/dev/null || stat -f%z "$SRC")
  echo "Uploading $DEST_KEY ($LOCAL_SIZE bytes)..."
  aws s3 cp "$SRC" "s3://${R2_BUCKET}/${DEST_KEY}" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type application/vnd.android.package-archive \
    --cache-control "public, max-age=31536000, immutable"
  REMOTE_SIZE=$(aws s3 ls "s3://${R2_BUCKET}/${DEST_KEY}" --endpoint-url "$R2_ENDPOINT" | awk '{print $3}')
  if [ "$REMOTE_SIZE" != "$LOCAL_SIZE" ]; then
    echo "ERROR: Upload size mismatch for $DEST_KEY (local=$LOCAL_SIZE remote=$REMOTE_SIZE)"
    exit 1
  fi
  echo "OK: $DEST_KEY verified ($REMOTE_SIZE bytes)"
}

upload_and_verify "$ARM64_APK" "OtyaPlayer-arm64.apk"
upload_and_verify "$ARM32_APK" "OtyaPlayer-arm32.apk"

# ── Generate version.json (Python reads changelog from file — no shell injection) ────
python3 - "$VERSION" "$VERSION_CODE" "$DATE" "$MIN_SDK" "$TARGET_SDK" "${WORKER_URL:-https://petersmartlink.com}" "$CHANGELOG_FILE" << 'PYEOF'
import json, sys
version, version_code, date, min_sdk, target_sdk, worker_url, changelog_file = sys.argv[1:]
with open(changelog_file) as f:
    changelog = f.read().strip() or 'Bug fixes and improvements'
data = {
    'version':     version,
    'versionCode': int(version_code),
    'date':        date,
    'arm64':       'OtyaPlayer-arm64.apk',
    'arm32':       'OtyaPlayer-arm32.apk',
    'changelog':   changelog,
    'minSdk':      int(min_sdk),
    'targetSdk':   int(target_sdk),
    'workerUrl':   worker_url,
    'downloads': {
        'arm64': f'{worker_url}/apk/arm64',
        'arm32': f'{worker_url}/apk/arm32',
        'auto':  f'{worker_url}/apk/arm64',
    },
}
with open('version.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print(json.dumps(data, indent=2))
PYEOF

python3 -c "import json; json.load(open('version.json'))" \
  || { echo "ERROR: version.json is not valid JSON"; exit 1; }

# ── Upload version.json LAST ───────────────────────────────────────────────────────────
echo "Uploading version.json..."
aws s3 cp version.json "s3://${R2_BUCKET}/version.json" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type application/json \
  --cache-control "public, max-age=300"
echo "OK: version.json uploaded"

# ── Purge KV cache ──────────────────────────────────────────────────────────────────
if [ -n "${CF_ACCOUNT_ID:-}" ] && [ -n "${CF_API_TOKEN:-}" ] && [ -n "${KV_NAMESPACE_ID:-}" ]; then
  echo "Purging KV cache key 'version:current'..."
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/version:current" \
    -H "Authorization: Bearer ${CF_API_TOKEN}")
  echo "KV purge HTTP: $HTTP"
else
  echo "INFO: KV purge skipped (CF vars not set) — new version live within 10 min"
fi

# ── Notify Appwrite ─────────────────────────────────────────────────────────────────
if [ -n "${APPWRITE_ENDPOINT:-}" ] && [ -n "${APPWRITE_PROJECT_ID:-}" ] && [ -n "${APPWRITE_API_KEY:-}" ]; then
  echo "Notifying Appwrite..."
  DOC_ID=$(echo "v${VERSION}" | tr '.' '-')
  DOC_BODY=$(python3 - "$VERSION" "$VERSION_CODE" "$DATE" "${WORKER_URL:-https://petersmartlink.com}" "$MIN_SDK" "$TARGET_SDK" "$CHANGELOG_FILE" << 'PYEOF'
import json, sys
version, version_code, date, worker_url, min_sdk, target_sdk, changelog_file = sys.argv[1:]
with open(changelog_file) as f:
    changelog = f.read().strip() or 'Bug fixes and improvements'
print(json.dumps({
    'documentId': f'v{version.replace(".", "-")}',
    'data': {
        'version':     version,
        'versionCode': int(version_code),
        'date':        date,
        'changelog':   changelog,
        'arm64Url':    f'{worker_url}/apk/arm64',
        'arm32Url':    f'{worker_url}/apk/arm32',
        'downloadUrl': f'{worker_url}/download',
        'minSdk':      int(min_sdk),
        'targetSdk':   int(target_sdk),
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
  echo "Appwrite HTTP: $HTTP_STATUS"
else
  echo "INFO: Appwrite vars not set — skipping"
fi

# -- Prune old backups (keep last 5) --
# head -n -5 exits non-zero on some systems when the list has fewer than 5
# entries, which aborts the script under set -euo pipefail even after a
# successful upload. Use an explicit count guard instead.
ALL_VERSIONS=$(aws s3 ls "s3://${R2_BUCKET}/releases/" \
  --endpoint-url "$R2_ENDPOINT" 2>/dev/null \
  | awk '{print $2}' | sort -V || true)
VERSION_COUNT=$(echo "$ALL_VERSIONS" | grep -c '.' 2>/dev/null || echo 0)
if [ "$VERSION_COUNT" -gt 5 ]; then
  PRUNE_COUNT=$((VERSION_COUNT - 5))
  TO_DELETE=$(echo "$ALL_VERSIONS" | head -n "$PRUNE_COUNT")
  for OLD in $TO_DELETE; do
    echo "Deleting old backup: $OLD"
    aws s3 rm "s3://${R2_BUCKET}/releases/${OLD}" \
      --endpoint-url "$R2_ENDPOINT" --recursive 2>/dev/null || true
  done
else
  echo "INFO: ${VERSION_COUNT} backup(s) found -- nothing to prune (keeping all <=5)"
fi

echo ""
echo "====================================================="
echo " OTYA Player v$VERSION published!"
echo " Live at: ${WORKER_URL:-https://petersmartlink.com}/download"
echo "====================================================="
