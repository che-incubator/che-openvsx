#!/bin/sh
#
# Publish extensions to the internal OpenVSX registry from a file containing VSIX URLs.
#
# Each non-empty, non-comment line in the input file is treated as a URL
# pointing to a .vsix file. The script downloads each file and publishes
# it using the ovsx CLI.
#
# Before publishing an extension, the script checks its dependencies via the
# upstream registry API. Any dependency not already present in the internal
# registry is automatically downloaded from the upstream and published first.
#
# Required environment variables:
#   OVSX_REGISTRY_URL   - Internal OpenVSX server URL (e.g. http://openvsx-server:8080/openvsx)
#   OVSX_PAT            - Personal Access Token for publishing
#
# Optional environment variables:
#   UPSTREAM_REGISTRY_URL  - Upstream registry URL (default: https://open-vsx.org)
#   OVSX_FORWARDED_HOST    - External hostname for X-Forwarded-Host header (fixes cached API URLs)
#   OVSX_FORWARDED_PROTO   - External scheme for X-Forwarded-Proto header (default: https)
#   NODE_EXTRA_CA_CERTS    - Path to CA bundle for self-signed certificates
#
# Usage:
#   publish-extensions.sh <extensions-file>
#

EXTENSIONS_FILE="${1:?Usage: publish-extensions.sh <extensions-file>}"
UPSTREAM_REGISTRY_URL="${UPSTREAM_REGISTRY_URL:-https://open-vsx.org}"

FORWARDED_HEADERS=""
if [ -n "$OVSX_FORWARDED_HOST" ]; then
  FORWARDED_HEADERS="-H X-Forwarded-Host:${OVSX_FORWARDED_HOST} -H X-Forwarded-Proto:${OVSX_FORWARDED_PROTO:-https}"
fi

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

# Track which extensions have already been published in this run to avoid
# duplicate work when multiple extensions share the same dependency.
PUBLISHED_DEPS=""

# ──────────────────────────────────────────────────────────────────────
# parse_extension_id <vsix-url>
#
# Extracts "namespace/name" from a .vsix URL.
#
# Handles two URL patterns:
#   open-vsx.org API URL: https://open-vsx.org/api/{ns}/{name}/{ver}/file/{file}.vsix
#   direct file URL:      https://example.com/path/{ns}.{name}-{ver}.vsix
# ──────────────────────────────────────────────────────────────────────
parse_extension_id() {
  local url="$1"
  local id filename bare namespace rest name

  # Try open-vsx.org API URL pattern:
  #   /api/{namespace}/{name}/{version}/file/...
  #   /api/{namespace}/{name}/{targetPlatform}/{version}/file/...
  id=$(echo "$url" | sed -n 's|.*/api/\([^/]*\)/\([^/]*\)/.*/file/.*|\1/\2|p')
  if [ -n "$id" ]; then
    echo "$id"
    return 0
  fi

  # Fall back to filename parsing: {namespace}.{name}-{version}[@targetPlatform].vsix
  filename=$(basename "$url")
  bare="${filename%.vsix}"
  bare="${bare%%@*}"
  namespace=$(echo "$bare" | cut -d. -f1)
  rest=$(echo "$bare" | cut -d. -f2-)
  name=$(echo "$rest" | sed 's/-[0-9][0-9.]*$//')

  if [ -n "$namespace" ] && [ -n "$name" ]; then
    echo "$namespace/$name"
    return 0
  fi

  return 1
}

# ──────────────────────────────────────────────────────────────────────
# is_installed <namespace> <name>
#
# Returns 0 if the extension is already published in the internal registry.
# ──────────────────────────────────────────────────────────────────────
is_installed() {
  local response version
  response=$(curl -fsSL $FORWARDED_HEADERS "$OVSX_REGISTRY_URL/api/$1/$2" 2>/dev/null) || return 1
  version=$(echo "$response" | jq -r '.version // empty')
  [ -n "$version" ]
}

# ──────────────────────────────────────────────────────────────────────
# publish_dependency <namespace> <name>
#
# Publishes a single dependency extension from the upstream registry.
# Downloads the latest version's VSIX and publishes it to the internal
# registry. Skips if already installed or already published in this run.
#
# This function is called recursively — if the dependency itself has
# dependencies, they are resolved first. A depth limit of 5 prevents
# infinite loops from circular dependencies.
# ──────────────────────────────────────────────────────────────────────
publish_dependency() {
  local dep_ns="$1"
  local dep_name="$2"
  local dep_depth="${3:-0}"
  local dep_id="$dep_ns/$dep_name"
  local dep_response dep_version dep_url dep_vsix DEP_OUTPUT DEP_RC

  # Depth limit to prevent infinite recursion from circular dependencies
  if [ "$dep_depth" -gt 5 ]; then
    echo "  WARN: Dependency resolution depth limit reached for $dep_id, skipping"
    return 1
  fi

  # Skip if already published in this run
  case ",$PUBLISHED_DEPS," in
    *",$dep_id,"*) return 0 ;;
  esac

  # Skip if already installed in the internal registry
  if is_installed "$dep_ns" "$dep_name"; then
    return 0
  fi

  echo "  Resolving dependency: $dep_id"

  # Recursively resolve this dependency's own dependencies first
  resolve_dependencies "$dep_ns" "$dep_name" $((dep_depth + 1))

  # Get the latest version from upstream
  dep_response=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$dep_ns/$dep_name" 2>/dev/null)
  dep_version=$(echo "$dep_response" | jq -r '.version // empty')

  if [ -z "$dep_version" ]; then
    echo "  WARN: Could not find $dep_id on upstream registry"
    return 1
  fi

  # Download the VSIX
  dep_url="$UPSTREAM_REGISTRY_URL/api/$dep_ns/$dep_name/$dep_version/file/$dep_ns.$dep_name-$dep_version.vsix"
  dep_vsix="$DOWNLOAD_DIR/$dep_ns.$dep_name-$dep_version.vsix"

  echo "  Downloading dependency: $dep_id $dep_version"
  if ! curl -fsSL -o "$dep_vsix" "$dep_url"; then
    echo "  WARN: Failed to download dependency $dep_id"
    return 1
  fi

  # Create namespace and publish
  ovsx create-namespace "$dep_ns" --pat "$OVSX_PAT" 2>/dev/null || true
  DEP_OUTPUT=$(ovsx publish "$dep_vsix" --pat "$OVSX_PAT" 2>&1) && DEP_RC=0 || DEP_RC=$?
  echo "  $DEP_OUTPUT"
  rm -f "$dep_vsix"

  if [ $DEP_RC -eq 0 ] || echo "$DEP_OUTPUT" | grep -q "is already published"; then
    PUBLISHED_DEPS="$PUBLISHED_DEPS,$dep_id"
    return 0
  fi

  echo "  WARN: Failed to publish dependency $dep_id"
  return 1
}

# ──────────────────────────────────────────────────────────────────────
# resolve_dependencies <namespace> <name> [depth]
#
# Queries the upstream registry for the extension's dependencies and
# publishes any that are missing from the internal registry.
# ──────────────────────────────────────────────────────────────────────
resolve_dependencies() {
  local ns="$1"
  local name="$2"
  local depth="${3:-0}"
  local response deps dep dep_ns dep_name

  # Query upstream for dependencies
  response=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$ns/$name" 2>/dev/null) || return 0
  deps=$(echo "$response" | jq -r '.dependencies[]? | "\(.namespace)/\(.extension)"' 2>/dev/null)

  if [ -z "$deps" ]; then
    return 0
  fi

  for dep in $deps; do
    dep_ns=$(echo "$dep" | cut -d/ -f1)
    dep_name=$(echo "$dep" | cut -d/ -f2)
    publish_dependency "$dep_ns" "$dep_name" "$depth" || true
  done
}

# ──────────────────────────────────────────────────────────────────────
# Main loop — process each extension in the list
# ──────────────────────────────────────────────────────────────────────
echo "=== Publishing extensions to $OVSX_REGISTRY_URL ==="
echo "Upstream registry: $UPSTREAM_REGISTRY_URL"
echo ""

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

  # Resolve and publish missing dependencies before publishing the extension
  ext_id=$(parse_extension_id "$line") || true
  if [ -n "$ext_id" ]; then
    ext_ns=$(echo "$ext_id" | cut -d/ -f1)
    ext_name=$(echo "$ext_id" | cut -d/ -f2)
    resolve_dependencies "$ext_ns" "$ext_name"
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

echo ""
echo "=== Done. Total: $TOTAL, Success: $SUCCESS, Failed: $FAILED ==="

if [ "$TOTAL" -gt 0 ] && [ "$SUCCESS" -eq 0 ]; then
  echo "ERROR: All extensions failed to publish"
  exit 1
fi
