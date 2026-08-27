#!/usr/bin/env bash
# scripts/publish_r2.sh
# Publishes verified OTYA release APKs to Cloudflare R2.
# GitHub is the source of truth; this script is intended for tagged/manual
# production releases only.
#
# Required env vars:
#   RELEASE_TAG (preferred, e.g. v1.6.0) or CI_COMMIT_TAG/GITHUB_REF_NAME
#   R2_ENDPOINT, R2_BUCKET, WORKER_URL
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
# Optional:
#   CF_ACCOUNT_ID, CF_API_TOKEN, KV_NAMESPACE_ID
#   OTYA_STORE_ADMIN_TOKEN

set -euo pipefail

# ── Resolve and validate release tag ──────────────────────────────────────────
RAW_TAG="${RELEASE_TAG:-${CI_COMMIT_TAG:-${GITHUB_REF_NAME:-}}}"
if [ -z "$RAW_TAG" ]; then
  echo "ERROR: No release tag found. Set RELEASE_TAG, CI_COMMIT_TAG or GITHUB_REF_NAME."
  exit 1
fi
if [[ ! "$RAW_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Invalid release tag '$RAW_TAG' (expected vX.Y.Z)."
  exit 1
fi
VERSION="${RAW_TAG#v}"

# Use pubspec versionCode (+N) if available, else derive from semver.
PUBSPEC_CODE=$(grep '^version:' pubspec.yaml | head -1 | grep -oP '(?<=\+)\d+' || echo "")
if [ -n "$PUBSPEC_CODE" ]; then
  VERSION_CODE="$PUBSPEC_CODE"
else
  VERSION_CODE=$(echo "$VERSION" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
fi
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "=== Publishing OTYA Player v$VERSION (versionCode=$VERSION_CODE) ==="

# ── Verify APK artifacts exist ────────────────────────────────────────────────
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

# ── Read changelog safely ─────────────────────────────────────────────────────
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

# Export values used by the server-notification Python process later.
export VERSION VERSION_CODE CHANGELOG_FILE

# ── Read SDK versions ─────────────────────────────────────────────────────────
MIN_SDK=$(grep 'minSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 24)
TARGET_SDK=$(grep 'targetSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 36)
echo "minSdk=$MIN_SDK  targetSdk=$TARGET_SDK"

# ── Backup current version ────────────────────────────────────────────────────
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

# ── Upload APKs with verification ─────────────────────────────────────────────
upload_and_verify() {
  local SRC="$1" DEST_KEY="$2"
  local LOCAL_SIZE REMOTE_SIZE
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

# ── Generate version.json ─────────────────────────────────────────────────────
python3 - "$VERSION" "$VERSION_CODE" "$DATE" "$MIN_SDK" "$TARGET_SDK" "${WORKER_URL:-https://petersmartlink.com}" "$CHANGELOG_FILE" << 'PYEOF'
import json, sys
version, version_code, date, min_sdk, target_sdk, worker_url, changelog_file = sys.argv[1:]
with open(changelog_file) as f:
    changelog = f.read().strip() or 'Bug fixes and improvements'
data = {
    'version': version,
    'versionCode': int(version_code),
    'date': date,
    'arm64': 'OtyaPlayer-arm64.apk',
    'arm32': 'OtyaPlayer-arm32.apk',
    'changelog': changelog,
    'minSdk': int(min_sdk),
    'targetSdk': int(target_sdk),
    'workerUrl': worker_url,
    'downloads': {
        'arm64': f'{worker_url}/apk/arm64',
        'arm32': f'{worker_url}/apk/arm32',
        'auto': f'{worker_url}/apk/arm64',
    },
}
with open('version.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print(json.dumps(data, indent=2))
PYEOF

python3 -c "import json; json.load(open('version.json'))" \
  || { echo "ERROR: version.json is not valid JSON"; exit 1; }

# ── Upload version.json LAST ──────────────────────────────────────────────────
echo "Uploading version.json..."
aws s3 cp version.json "s3://${R2_BUCKET}/version.json" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type application/json \
  --cache-control "public, max-age=300"
echo "OK: version.json uploaded"

# ── Purge stale version cache ─────────────────────────────────────────────────
if [ -n "${CF_ACCOUNT_ID:-}" ] && [ -n "${CF_API_TOKEN:-}" ] && [ -n "${KV_NAMESPACE_ID:-}" ]; then
  echo "Purging KV cache key 'version:current'..."
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/version:current" \
    -H "Authorization: Bearer ${CF_API_TOKEN}")
  echo "KV purge HTTP: $HTTP"
else
  echo "INFO: KV purge skipped (Cloudflare vars not set)"
fi

# ── Notify otya-store release API ─────────────────────────────────────────────
# Non-fatal: R2 publication remains authoritative even if D1 notification fails.
if [ -n "${WORKER_URL:-}" ] && [ -n "${OTYA_STORE_ADMIN_TOKEN:-}" ]; then
  echo "Notifying server of new release v$VERSION..."
  python3 - <<'PYEOF'
import json, hmac, hashlib, time, urllib.request, urllib.error, os

worker_url = os.environ['WORKER_URL'].rstrip('/')
secret = os.environ['OTYA_STORE_ADMIN_TOKEN']
version = os.environ['VERSION']
version_code = int(os.environ['VERSION_CODE'])
tag = 'v' + version

try:
    with open(os.environ['CHANGELOG_FILE']) as f:
        changelog = f.read().strip() or 'Bug fixes and improvements'
except Exception:
    changelog = 'Bug fixes and improvements'

path = '/api/admin/release'
timestamp = str(int(time.time()))
signing = f'POST:{path}:{timestamp}'
sig = hmac.new(secret.encode(), signing.encode(), hashlib.sha256).hexdigest()

payload = json.dumps({
    'tag': tag,
    'version': version,
    'version_code': version_code,
    'changelog': changelog,
}).encode()

req = urllib.request.Request(
    f'{worker_url}{path}',
    data=payload,
    method='POST',
    headers={
        'Content-Type': 'application/json',
        'X-Otya-Timestamp': timestamp,
        'X-Otya-Signature': sig,
    },
)
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read().decode()
        print(f'Server notified OK ({resp.status}): {body[:120]}')
except urllib.error.HTTPError as e:
    print(f'WARNING: Server notify failed HTTP {e.code}: {e.read().decode()[:200]}')
except Exception as e:
    print(f'WARNING: Server notify failed: {e}')
PYEOF
else
  echo "INFO: WORKER_URL or OTYA_STORE_ADMIN_TOKEN not set — skipping server notify"
fi

# ── Write latest release metadata to KV ───────────────────────────────────────
if [ -n "${CF_ACCOUNT_ID:-}" ] && [ -n "${CF_API_TOKEN:-}" ] && [ -n "${KV_NAMESPACE_ID:-}" ]; then
  echo "Writing LATEST_BUILD_INFO to KV..."
  KV_VALUE=$(cat version.json)
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT \
    "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/LATEST_BUILD_INFO" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data-raw "$KV_VALUE")
  echo "KV write LATEST_BUILD_INFO HTTP: $HTTP"
else
  echo "INFO: Cloudflare vars not set — skipping KV LATEST_BUILD_INFO write"
fi

# ── Prune old backups (keep last 5) ───────────────────────────────────────────
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
  echo "INFO: ${VERSION_COUNT} backup(s) found — nothing to prune"
fi

echo ""
echo "====================================================="
echo " OTYA Player v$VERSION published!"
echo " Live at: ${WORKER_URL:-https://petersmartlink.com}/download"
echo "====================================================="
