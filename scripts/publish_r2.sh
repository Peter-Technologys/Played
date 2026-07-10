#!/usr/bin/env bash
# Called by GitLab CI publish_to_r2 job.
# All secrets come from CI environment variables.
set -euo pipefail

VERSION=${CI_COMMIT_TAG#v}
VERSION_CODE=$(echo "$VERSION" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "=== Publishing OTYA Player v$VERSION (code $VERSION_CODE) ==="

# Read changelog from CHANGELOG.md (top versioned section)
CHANGELOG=$(awk '/^## \[/{found++} found==1{print} found==2{exit}' CHANGELOG.md \
  | tail -n +2 | head -40 | tr '\n' ' ' \
  | sed 's/  */ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')
[ -z "$CHANGELOG" ] && CHANGELOG="Bug fixes and improvements"

# Read SDK versions from build.gradle
MIN_SDK=$(grep 'minSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 21)
TARGET_SDK=$(grep 'targetSdk' android/app/build.gradle | grep -v '//' | head -1 | grep -oP '\d+' || echo 36)
echo "minSdk=$MIN_SDK  targetSdk=$TARGET_SDK"

# Backup current version before overwriting
CURRENT_VERSION=$(aws s3 cp \
  "s3://${R2_BUCKET}/version.json" - \
  --endpoint-url "$R2_ENDPOINT" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version',''))" 2>/dev/null \
  || echo "")

if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "$VERSION" ]; then
  echo "Backing up v$CURRENT_VERSION to releases/v$CURRENT_VERSION/..."
  # Filenames match the no-flavor artifact paths produced by build_release.
  for KEY in app-arm64-v8a-release.apk app-armeabi-v7a-release.apk version.json; do
    aws s3 cp \
      "s3://${R2_BUCKET}/${KEY}" \
      "s3://${R2_BUCKET}/releases/v${CURRENT_VERSION}/${KEY}" \
      --endpoint-url "$R2_ENDPOINT" 2>/dev/null || true
  done
fi

# Upload APKs
echo "Uploading arm64 APK..."
aws s3 cp \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  "s3://${R2_BUCKET}/app-arm64-v8a-release.apk" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type application/vnd.android.package-archive \
  --cache-control "public, max-age=31536000, immutable"

echo "Uploading arm32 APK..."
aws s3 cp \
  build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk \
  "s3://${R2_BUCKET}/app-armeabi-v7a-release.apk" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type application/vnd.android.package-archive \
  --cache-control "public, max-age=31536000, immutable"

# Generate version.json
python3 - <<PYEOF
import json
data = {
    "version":     "${VERSION}",
    "versionCode": int("${VERSION_CODE}"),
    "date":        "${DATE}",
    # Filenames match the no-flavor artifact paths produced by build_release.
    "arm64":       "app-arm64-v8a-release.apk",
    "arm32":       "app-armeabi-v7a-release.apk",
    "changelog":   """${CHANGELOG}""",
    "minSdk":      int("${MIN_SDK}"),
    "targetSdk":   int("${TARGET_SDK}"),
    "workerUrl":   "${WORKER_URL}"
}
with open("version.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(json.dumps(data, indent=2))
PYEOF

# Validate
python3 -c "import json; json.load(open('version.json'))" || { echo "ERROR: invalid version.json"; exit 1; }

# Upload version.json LAST (Worker is always consistent)
echo "Uploading version.json..."
aws s3 cp \
  version.json \
  "s3://${R2_BUCKET}/version.json" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type application/json \
  --cache-control "public, max-age=300"

echo "R2 upload complete."

# Notify Appwrite
if [ -n "${APPWRITE_ENDPOINT:-}" ] && [ -n "${APPWRITE_PROJECT_ID:-}" ] && [ -n "${APPWRITE_API_KEY:-}" ]; then
  echo "Notifying Appwrite..."
  DOC_ID=$(echo "v${VERSION}" | tr '.' '-')
  DOC_BODY=$(python3 - <<PYEOF2
import json
print(json.dumps({
    "documentId": "${DOC_ID}",
    "data": {
        "version":     "${VERSION}",
        "versionCode": int("${VERSION_CODE}"),
        "date":        "${DATE}",
        "changelog":   """${CHANGELOG}""",
        "arm64Url":    "${WORKER_URL}/apk/arm64",
        "arm32Url":    "${WORKER_URL}/apk/arm32",
        "downloadUrl": "${WORKER_URL}/download",
        "minSdk":      int("${MIN_SDK}"),
        "targetSdk":   int("${TARGET_SDK}")
    }
}))
PYEOF2
)
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    "${APPWRITE_ENDPOINT}/databases/otya-db/collections/releases/documents" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: ${APPWRITE_PROJECT_ID}" \
    -H "X-Appwrite-Key: ${APPWRITE_API_KEY}" \
    -d "$DOC_BODY")
  echo "Appwrite response: $HTTP_STATUS"
else
  echo "APPWRITE vars not set - skipping notification."
fi

# Prune old backups (keep last 5)
echo "Pruning old backups..."
VERSIONS=$(aws s3 ls "s3://${R2_BUCKET}/releases/" \
  --endpoint-url "$R2_ENDPOINT" 2>/dev/null \
  | awk '{print $2}' | sort -V | head -n -5)
for OLD in $VERSIONS; do
  echo "Deleting old backup: $OLD"
  aws s3 rm "s3://${R2_BUCKET}/releases/${OLD}" \
    --endpoint-url "$R2_ENDPOINT" --recursive 2>/dev/null || true
done

echo "Done. Live at ${WORKER_URL}"
