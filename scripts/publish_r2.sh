#!/usr/bin/env bash
# Publishes verified OTYA release APKs to Cloudflare R2, then starts the
# durable Cloudflare release Workflow and waits for a terminal result.

set -euo pipefail

RAW_TAG="${RELEASE_TAG:-${CI_COMMIT_TAG:-${GITHUB_REF_NAME:-}}}"
[ -n "$RAW_TAG" ] || { echo "ERROR: No release tag found"; exit 1; }
[[ "$RAW_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: Invalid release tag '$RAW_TAG'"; exit 1; }
VERSION="${RAW_TAG#v}"

PUBSPEC_CODE=$(grep '^version:' pubspec.yaml | head -1 | grep -oP '(?<=\+)\d+' || echo "")
if [ -n "$PUBSPEC_CODE" ]; then
  VERSION_CODE="$PUBSPEC_CODE"
else
  VERSION_CODE=$(echo "$VERSION" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
fi
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
WORKER_URL="${WORKER_URL:-https://petersmartlink.com}"
WORKER_URL="${WORKER_URL%/}"

: "${R2_ENDPOINT:?R2_ENDPOINT is required}"
: "${R2_BUCKET:?R2_BUCKET is required}"
: "${OTYA_STORE_ADMIN_TOKEN:?OTYA_STORE_ADMIN_TOKEN is required}"

ARM64_APK="${ARM64_APK:-build/app/outputs/flutter-apk/app-arm64-v8a-release.apk}"
ARM32_APK="${ARM32_APK:-build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk}"
for APK in "$ARM64_APK" "$ARM32_APK"; do
  test -f "$APK" || { echo "ERROR: APK not found: $APK"; exit 1; }
  SIZE=$(stat -c%s "$APK" 2>/dev/null || stat -f%z "$APK")
  [ "$SIZE" -ge 5000000 ] || { echo "ERROR: $APK looks too small ($SIZE bytes)"; exit 1; }
done

CHANGELOG_FILE=$(mktemp)
trap 'rm -f "$CHANGELOG_FILE"' EXIT
awk '/^## \[/{found++} found==1{print} found==2{exit}' CHANGELOG.md \
  | tail -n +2 | head -40 | tr '\n' ' ' \
  | sed 's/  */ /g; s/^[[:space:]]*//; s/[[:space:]]*$//' > "$CHANGELOG_FILE"
CHANGELOG=$(cat "$CHANGELOG_FILE")
[ -n "$CHANGELOG" ] || CHANGELOG="Bug fixes and improvements"

MIN_SDK=$(grep 'minSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 24)
TARGET_SDK=$(grep 'targetSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 36)

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

ARM64_VERSIONED="releases/${RAW_TAG}/OTYA-Player-${RAW_TAG}-arm64.apk"
ARM32_VERSIONED="releases/${RAW_TAG}/OTYA-Player-${RAW_TAG}-arm32.apk"

# Versioned artifacts are immutable. Latest aliases are deliberately short-lived.
upload_and_verify "$ARM64_APK" "$ARM64_VERSIONED" "public, max-age=31536000, immutable"
upload_and_verify "$ARM32_APK" "$ARM32_VERSIONED" "public, max-age=31536000, immutable"
upload_and_verify "$ARM64_APK" "OtyaPlayer-arm64.apk" "public, max-age=300, must-revalidate"
upload_and_verify "$ARM32_APK" "OtyaPlayer-arm32.apk" "public, max-age=300, must-revalidate"

python3 - "$VERSION" "$VERSION_CODE" "$DATE" "$MIN_SDK" "$TARGET_SDK" "$WORKER_URL" "$CHANGELOG_FILE" "$ARM64_VERSIONED" "$ARM32_VERSIONED" <<'PYEOF'
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

# Start the durable backend release workflow. It re-verifies the R2 artifacts,
# safely updates D1/KV metadata, writes Analytics Engine data and emits the
# deduplicated update notification.
export RAW_TAG VERSION VERSION_CODE MIN_SDK TARGET_SDK WORKER_URL CHANGELOG_FILE ARM64_VERSIONED ARM32_VERSIONED OTYA_STORE_ADMIN_TOKEN
WORKFLOW_ID=$(python3 - <<'PYEOF'
import json, os, sys, urllib.request, urllib.error
with open(os.environ['CHANGELOG_FILE']) as f:
    changelog = f.read().strip() or 'Bug fixes and improvements'
payload = {
    'tag': os.environ['RAW_TAG'],
    'version': os.environ['VERSION'],
    'versionCode': int(os.environ['VERSION_CODE']),
    'arm64Key': os.environ['ARM64_VERSIONED'],
    'arm32Key': os.environ['ARM32_VERSIONED'],
    'changelog': changelog,
    'minSdk': int(os.environ['MIN_SDK']),
    'targetSdk': int(os.environ['TARGET_SDK']),
    'workerUrl': os.environ['WORKER_URL'],
}
req = urllib.request.Request(
    os.environ['WORKER_URL'] + '/api/admin/release-workflow',
    data=json.dumps(payload).encode(), method='POST',
    headers={
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + os.environ['OTYA_STORE_ADMIN_TOKEN'],
    },
)
try:
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.load(resp)
except urllib.error.HTTPError as e:
    sys.stderr.write(f'ERROR: release workflow start failed HTTP {e.code}\n')
    sys.exit(1)
except Exception as e:
    sys.stderr.write(f'ERROR: release workflow start failed: {type(e).__name__}\n')
    sys.exit(1)
instance_id = data.get('instanceId')
if not instance_id:
    sys.stderr.write('ERROR: release workflow returned no instanceId\n')
    sys.exit(1)
print(instance_id)
PYEOF
)

echo "Cloudflare release workflow instance: $WORKFLOW_ID"
export WORKFLOW_ID

python3 - <<'PYEOF'
import json, os, sys, time, urllib.parse, urllib.request, urllib.error
base = os.environ['WORKER_URL'] + '/api/admin/release-workflow/status?id=' + urllib.parse.quote(os.environ['WORKFLOW_ID'])
headers = {'Authorization': 'Bearer ' + os.environ['OTYA_STORE_ADMIN_TOKEN']}
terminal_fail = {'errored', 'terminated', 'unknown'}
for attempt in range(60):
    req = urllib.request.Request(base, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.load(resp)
    except Exception as e:
        if attempt >= 59:
            sys.stderr.write(f'ERROR: could not read workflow status: {type(e).__name__}\n')
            sys.exit(1)
        time.sleep(5)
        continue
    workflow = data.get('workflow') or {}
    status = workflow.get('status')
    print(f'Workflow status: {status}')
    if status == 'complete':
        output = workflow.get('output')
        if isinstance(output, dict) and output.get('ok') is False:
            sys.stderr.write('ERROR: workflow completed with unsuccessful output\n')
            sys.exit(1)
        sys.exit(0)
    if status in terminal_fail:
        error = workflow.get('error') or {}
        sys.stderr.write('ERROR: release workflow failed: ' + str(error.get('message') or status) + '\n')
        sys.exit(1)
    time.sleep(5)
sys.stderr.write('ERROR: release workflow did not finish within the polling window\n')
sys.exit(1)
PYEOF

echo "====================================================="
echo " OTYA Player ${RAW_TAG} published and workflow verified"
echo " Download: ${WORKER_URL}/download/otya-player"
echo "====================================================="
