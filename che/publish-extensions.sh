#!/bin/sh
#
# Publish extensions to the OpenVSX registry from a file containing VSIX URLs.
#
# Each non-empty, non-comment line in the input file is treated as a URL
# pointing to a .vsix file. The script downloads each file and publishes
# it using the ovsx CLI.
#
# Required environment variables:
#   OVSX_REGISTRY_URL  - OpenVSX server URL (e.g. https://openvsx-eclipse-che.apps.example.com)
#   OVSX_PAT           - Personal Access Token for publishing
#
# Optional environment variables:
#   NODE_EXTRA_CA_CERTS - Path to CA bundle for self-signed certificates
#
# Usage:
#   publish-extensions.sh <extensions-file>
#

set -e

EXTENSIONS_FILE="${1:?Usage: publish-extensions.sh <extensions-file>}"

if [ ! -f "$EXTENSIONS_FILE" ]; then
  echo "ERROR: Extensions file not found: $EXTENSIONS_FILE"
  exit 1
fi

if [ -z "$OVSX_REGISTRY_URL" ]; then
  echo "ERROR: OVSX_REGISTRY_URL is not set"
  exit 1
fi

if [ -z "$OVSX_PAT" ]; then
  echo "ERROR: OVSX_PAT is not set"
  exit 1
fi

DOWNLOAD_DIR=$(mktemp -d)
trap 'rm -rf "$DOWNLOAD_DIR"' EXIT

TOTAL=0
SUCCESS=0
FAILED=0

echo "Publishing extensions to $OVSX_REGISTRY_URL"

while IFS= read -r line || [ -n "$line" ]; do
  # Skip empty lines and comments
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$line" in
    ""|\#*) continue ;;
  esac

  TOTAL=$((TOTAL + 1))
  FILENAME=$(basename "$line")
  VSIX_PATH="$DOWNLOAD_DIR/$FILENAME"

  echo "---"
  echo "Downloading: $line"
  if ! curl -fsSL -o "$VSIX_PATH" "$line"; then
    echo "WARN: Failed to download $line, skipping"
    FAILED=$((FAILED + 1))
    continue
  fi

  NAMESPACE=$(echo "$FILENAME" | cut -d. -f1)
  if [ -n "$NAMESPACE" ]; then
    echo "Ensuring namespace exists: $NAMESPACE"
    ovsx create-namespace "$NAMESPACE" --pat "$OVSX_PAT" 2>/dev/null || true
  fi

  echo "Publishing: $FILENAME"
  PUBLISH_OUTPUT=$(ovsx publish "$VSIX_PATH" --pat "$OVSX_PAT" 2>&1) && PUBLISH_RC=0 || PUBLISH_RC=$?
  echo "$PUBLISH_OUTPUT"
  if [ $PUBLISH_RC -eq 0 ] || echo "$PUBLISH_OUTPUT" | grep -q "is already published"; then
    SUCCESS=$((SUCCESS + 1))
  else
    echo "WARN: Failed to publish $FILENAME"
    FAILED=$((FAILED + 1))
  fi

  rm -f "$VSIX_PATH"
done < "$EXTENSIONS_FILE"

echo "---"
echo "Done. Total: $TOTAL, Success: $SUCCESS, Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
