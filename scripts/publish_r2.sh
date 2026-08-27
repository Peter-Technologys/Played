#!/usr/bin/env bash
# scripts/publish_r2.sh
# Publishes verified OTYA release APKs to Cloudflare R2.
# GitHub is the source of truth; this script is intended for tagged/manual
# production releases only.

set -euo pipefail

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

PUBSPEC_CODE=$(grep '^version:' pubspec.yaml | head -1 | grep -oP '(?<=\+)\d+' || echo "")
if [ -n "$PUBSPEC_CODE" ]; then
  VERSION_CODE="$PUBSPEC_CODE"
else
  VERSION_CODE=$(echo "$VERSION" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
fi
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "=== Publishing OTYA Player v$VERSION (versionCode=$VERSION_CODE) ==="

ARM64_APK="${ARM64_APK:-build/app/outputs/flutter-apk/app-arm64-v8a-release.apk}"
ARM32_APK="${ARM32_APK:-build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk}"
for APK in "$ARM64_APK" "$ARM32_APK"; do
  if [ ! -f "$APK" ]; then
    echo "ERROR: APK not found: $APK"
    exit 1
  fi
  SIZE=$(stat -c%s "$APK" 2>/dev/null || stat -f%z "$APK")
  [ "$SIZE" -ge 5000000 ] || { echo "ERROR: $APK looks too small ($SIZE bytes)"; exit 1; }
done

CHANGELOG_FILE=$(mktemp)
trap 'rm -f "$CHANGELOG_FILE"' EXIT
awk '/^## \[/{found++} found==1{print} found==2{exit}' CHANGELOG.md \
  | tail -n +2 | head -40 | tr '\n' ' ' \
  | sed 's/  */ /g; s/^[[:space:]]*//; s/[[:space:]]*$//' > "$CHANGELOG_FILE"
CHANGELOG=$(cat "$CHANGELOG_FILE")
[ -z "$CHANGELOG" ] && CHANGELOG="Bug fixes and improvements"
export VERSION VERSION_CODE CHANGELOG_FILE

MIN_SDK=$(grep 'minSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 24)
TARGET_SDK=$(grep 'targetSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 36)

CURRENT_VERSION=$(aws s3 cp "s3://${R2_BUCKET}/version.json" - --endpoint-url "$R2_ENDPOINT" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version',''))" 2>/dev/null || echo "")
if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "$VERSION" ]; then
  echo "Previous live version: v$CURRENT_VERSION"
fi

upload_and_verify() {
  local SRC="$1" DEST_KEY="$2" CACHE_CONTROL="$3"
  local LOCAL_SIZE REMOTE_SIZE
  LOCAL_SIZE=$(stat -c%s "$SRC" 2>/dev/null || stat -f%z "$SRC")
  echo "Uploading $DEST_KEY ($LOCAL_SIZE bytes)..."
  aws s3 cp "$SRC" "s3://${R2_BUCKET}/${DEST_KEY}" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type application/vnd.android.package-archive \
    --cache-control "$CACHE_CONTROL"
  REMOTE_SIZE=$(aws s3 ls "s3://${R2_BUCKET}/${DEST_KEY}" --endpoint-url "$R2_ENDPOINT" | awk '{print $3}')
  [ "$REMOTE_SIZE" = "$LOCAL_SIZE" ] || { echo "ERROR: Upload size mismatch for $DEST_KEY"; exit 1; }
}

ARM64_VERSIONED="releases/v${VERSION}/OTYA-Player-v${VERSION}-arm64.apk"
ARM32_VERSIONED="releases/v${VERSION}/OTYA-Player-v${VERSION}-arm32.apk"
upload_and_verify "$ARM64_APK" "$ARM64_VERSIONED" "public, max-age=31536000, immutable"
upload_and_verify "$ARM32_APK" "$ARM32_VERSIONED" "public, max-age=31536000, immutable"
upload_and_verify "$ARM64_APK" "OtyaPlayer-arm64.apk" "public, max-age=300, must-revalidate"
upload_and_verify "$ARM32_APK" "OtyaPlayer-arm32.apk" "public, max-age=300, must-revalidate"

python3 - "$VERSION" "$VERSION_CODE" "$DATE" "$MIN_SDK" "$TARGET_SDK" "${WORKER_URL:-https://petersmartlink.com}" "$CHANGELOG_FILE" "$ARM64_VERSIONED" "$ARM32_VERSIONED" << 'PYEOF'
import json, sys
version, version_code, date, min_sdk, target_sdk, worker_url, changelog_file, arm64_key, arm32_key = sys.argv[1:]
with open(changelog_file) as f:
    changelog = f.read().strip() or 'Bug fixes and improvements'
data = {
    'version': version,
    'versionCode': int(version_code),
    'date': date,
    'arm64': arm64_key,
    'arm32': arm32_key,
    'latestAliases': {'arm64': 'OtyaPlayer-arm64.apk', 'arm32': 'OtyaPlayer-arm32.apk'},
    'changelog': changelog,
    'minSdk': int(min_sdk),
    'targetSdk': int(target_sdk),
    'workerUrl': worker_url,
    'downloads': {
        'arm64': f'{worker_url}/apk/arm64',
        'arm32': f'{worker_url}/apk/arm32',
        'auto': f'{worker_url}/apk/arm64',
        'page': f'{worker_url}/download/otya-player',
    },
}
with open('version.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
python3 -c "import json; json.load(open('version.json'))"

aws s3 cp version.json "s3://${R2_BUCKET}/version.json" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type application/json \
  --cache-control "public, max-age=300, must-revalidate"

if [ -n "${CF_ACCOUNT_ID:-}" ] && [ -n "${CF_API_TOKEN:-}" ] && [ -n "${KV_NAMESPACE_ID:-}" ]; then
  curl -fsS -X DELETE \
    "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/version:current" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" >/dev/null || true
fi

# Keep the release API synchronized with R2/KV. The backend contract is Bearer ADMIN_TOKEN.
if [ -n "${WORKER_URL:-}" ] && [ -n "${OTYA_STORE_ADMIN_TOKEN:-}" ]; then
  HTTP=$(python3 - <<'PYEOF'
import json, urllib.request, urllib.error, os
worker_url = os.environ['WORKER_URL'].rstrip('/')
secret = os.environ['OTYA_STORE_ADMIN_TOKEN']
version = os.environ['VERSION']
version_code = int(os.environ['VERSION_CODE'])
with open(os.environ['CHANGELOG_FILE']) as f:
    changelog = f.read().strip() or 'Bug fixes and improvements'
payload = json.dumps({'tag':'v'+version,'version':version,'version_code':version_code,'changelog':changelog}).encode()
req = urllib.request.Request(
    f'{worker_url}/api/admin/release', data=payload, method='POST',
    headers={'Content-Type':'application/json','Authorization':f'Bearer {secret}'})
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        print(resp.status)
except urllib.error.HTTPError as e:
    print(e.code)
except Exception:
    print(0)
PYEOF
)
  [[ "$HTTP" =~ ^2 ]] || { echo "ERROR: Server release notification failed HTTP $HTTP"; exit 1; }
else
  echo "INFO: release API notification skipped because WORKER_URL or OTYA_STORE_ADMIN_TOKEN is missing"
fi

if [ -n "${CF_ACCOUNT_ID:-}" ] && [ -n "${CF_API_TOKEN:-}" ] && [ -n "${KV_NAMESPACE_ID:-}" ]; then
  KV_VALUE=$(cat version.json)
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/storage/kv/namespaces/${KV_NAMESPACE_ID}/values/LATEST_BUILD_INFO" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" --data-raw "$KV_VALUE")
  [[ "$HTTP" =~ ^2 ]] || { echo "ERROR: KV LATEST_BUILD_INFO write failed HTTP $HTTP"; exit 1; }
fi

echo "====================================================="
echo " OTYA Player v$VERSION published"
echo " Download: ${WORKER_URL:-https://petersmartlink.com}/download/otya-player"
echo "====================================================="
