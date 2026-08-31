#!/usr/bin/env bash
# Publishes immutable OTYA release APKs to Cloudflare R2, then starts the
# durable Cloudflare release Workflow and waits for a terminal result.
# Canonical version metadata is published by the backend Workflow only after
# it has verified both APKs and accepted the release version code.

set -euo pipefail

RAW_TAG="${RELEASE_TAG:-${CI_COMMIT_TAG:-${GITHUB_REF_NAME:-}}}"
[ -n "$RAW_TAG" ] || { echo "ERROR: No release tag found"; exit 1; }
[[ "$RAW_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: Invalid release tag '$RAW_TAG'"; exit 1; }
VERSION="${RAW_TAG#v}"

PUBSPEC_VERSION=$(awk '/^version:/ {print $2; exit}' pubspec.yaml)
[ -n "$PUBSPEC_VERSION" ] || { echo "ERROR: pubspec.yaml has no version"; exit 1; }
PUBSPEC_NAME="${PUBSPEC_VERSION%%+*}"
PUBSPEC_CODE="${PUBSPEC_VERSION##*+}"
[ "$PUBSPEC_NAME" = "$VERSION" ] || {
  echo "ERROR: release tag $RAW_TAG does not match pubspec version $PUBSPEC_NAME"
  exit 1
}
[[ "$PUBSPEC_CODE" =~ ^[1-9][0-9]*$ ]] || {
  echo "ERROR: pubspec Android build number must be a positive integer"
  exit 1
}
VERSION_CODE="$PUBSPEC_CODE"

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

# Upload immutable candidate artifacts first. These keys are not canonical
# release pointers, so a later validation failure cannot replace /latest.
upload_and_verify "$ARM64_APK" "$ARM64_VERSIONED" "public, max-age=31536000, immutable"
upload_and_verify "$ARM32_APK" "$ARM32_VERSIONED" "public, max-age=31536000, immutable"

# Start the durable backend release workflow. It re-verifies the R2 artifacts,
# enforces monotonic Android version codes, safely updates D1/KV, publishes the
# canonical R2 version.json, writes analytics and emits the deduplicated update
# notification. The shell script never writes version.json itself.
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
import json, os, sys, time, urllib.parse, urllib.request
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

# Legacy aliases are compatibility conveniences only. Publish them after the
# canonical release has completed so an aborted candidate can never replace a
# "latest" raw R2 object. Failure here is reported as a warning because the
# canonical /apk routes use the versioned keys from version.json.
if ! upload_and_verify "$ARM64_APK" "OtyaPlayer-arm64.apk" "public, max-age=300, must-revalidate"; then
  echo "WARNING: canonical release succeeded but the legacy arm64 alias could not be refreshed"
fi
if ! upload_and_verify "$ARM32_APK" "OtyaPlayer-arm32.apk" "public, max-age=300, must-revalidate"; then
  echo "WARNING: canonical release succeeded but the legacy arm32 alias could not be refreshed"
fi

echo "====================================================="
echo " OTYA Player ${RAW_TAG} published and workflow verified"
echo " Download: ${WORKER_URL}/download/otya-player"
echo "====================================================="
