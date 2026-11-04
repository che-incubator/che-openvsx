#!/bin/sh
#
# Publish extensions to the internal OpenVSX registry.
#
# Each non-empty, non-comment line in the input file is one of:
#   namespace.name            - publish the latest stable version
#   namespace.name@version    - publish a specific version
#   https://...vsix           - download and publish from a direct URL (legacy)
#
# Before publishing an extension, the script checks its dependencies via the
# upstream registry API. Any dependency not already present in the internal
# registry is automatically downloaded from the upstream and published first.
#
# For identifier-format entries, a universal VSIX is tried first. If it does
# not exist and an architecture is configured, the platform-specific VSIX is
# used as a fallback. The architecture is read from an "architecture" file in
# the same directory as the extensions file (e.g. from the same ConfigMap),
# or from the ARCHITECTURE environment variable.
#
# Required environment variables:
#   OVSX_REGISTRY_URL   - Internal OpenVSX server URL (e.g. http://openvsx-server:8080/openvsx)
#   OVSX_PAT            - Personal Access Token for publishing
#
# Optional environment variables:
#   UPSTREAM_REGISTRY_URL  - Upstream registry URL (default: https://open-vsx.org)
#   ARCHITECTURE           - Target platform fallback (e.g. linux-x64) when no universal VSIX exists
#   OVSX_FORWARDED_HOST    - External hostname for X-Forwarded-Host header (fixes cached API URLs)
#   OVSX_FORWARDED_PROTO   - External scheme for X-Forwarded-Proto header (default: https)
#   NODE_EXTRA_CA_CERTS    - Path to CA bundle for self-signed certificates
#
# Usage:
#   publish-extensions.sh <extensions-file>
#

EXTENSIONS_FILE="${1:?Usage: publish-extensions.sh <extensions-file>}"
UPSTREAM_REGISTRY_URL="${UPSTREAM_REGISTRY_URL:-https://open-vsx.org}"

# Read architecture from the ConfigMap-mounted file alongside extensions.list, or from env.
ARCHITECTURE_FILE="$(dirname "$EXTENSIONS_FILE")/architecture"
ARCHITECTURE="${ARCHITECTURE:-$(cat "$ARCHITECTURE_FILE" 2>/dev/null | tr -d '[:space:]')}"

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
# parse_identifier <line>
#
# If the line is a "namespace.name" or "namespace.name@version" identifier
# (not a URL), prints "namespace/name/version" (version may be empty) and
# returns 0. Returns 1 for URL-format lines.
# ──────────────────────────────────────────────────────────────────────
parse_identifier() {
  case "$1" in
    *://*) return 1 ;;
  esac

  local ns name_ver name version
  ns=$(echo "$1" | cut -d. -f1)
  name_ver=$(echo "$1" | cut -d. -f2-)
  name=$(echo "$name_ver" | cut -d@ -f1)
  version=$(echo "$name_ver" | grep -o '@.*' | cut -c2-)

  [ -n "$ns" ] && [ -n "$name" ] || return 1
  printf '%s/%s/%s' "$ns" "$name" "${version:-}"
}

# ──────────────────────────────────────────────────────────────────────
# get_latest_release_version <namespace> <name>
#
# Finds the latest non-pre-release version from the upstream registry.
# Prints the version string, or empty if no release version exists.
# ──────────────────────────────────────────────────────────────────────
get_latest_release_version() {
  local ns="$1"
  local ext="$2"
  local page_size=20
  local offset=0
  local latest_response is_pre max_check checked page total_size versions ver ver_response ver_pre

  latest_response=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$ns/$ext" 2>/dev/null) || return 0
  is_pre=$(echo "$latest_response" | jq -r '.preRelease // false')
  if [ "$is_pre" != "true" ]; then
    echo "$latest_response" | jq -r '.version // empty'
    return 0
  fi

  max_check="${MAX_VERSIONS_TO_CHECK:-50}"
  checked=0

  while [ "$checked" -lt "$max_check" ]; do
    page=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$ns/$ext/versions?size=$page_size&offset=$offset" 2>/dev/null) || return 0
    total_size=$(echo "$page" | jq -r '.totalSize // 0')
    versions=$(echo "$page" | jq -r '.versions | keys[]' 2>/dev/null)

    if [ -z "$versions" ]; then
      return 0
    fi

    for ver in $(echo "$versions" | sort -rV); do
      checked=$((checked + 1))
      if [ "$checked" -gt "$max_check" ]; then
        return 0
      fi

      ver_response=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$ns/$ext/$ver" 2>/dev/null) || continue
      ver_pre=$(echo "$ver_response" | jq -r '.preRelease // false')
      if [ "$ver_pre" != "true" ]; then
        echo "$ver"
        return 0
      fi
    done

    offset=$((offset + page_size))
    if [ "$offset" -ge "$total_size" ]; then
      return 0
    fi
  done
}

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
if [ -n "$ARCHITECTURE" ]; then
  echo "Architecture fallback: $ARCHITECTURE"
fi
echo ""

while IFS= read -r line || [ -n "$line" ]; do
  # Skip empty lines and comments
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$line" in
    ""|\#*) continue ;;
  esac

  TOTAL=$((TOTAL + 1))
  echo "---"

  if id_info=$(parse_identifier "$line"); then
    # ── Identifier format: namespace.name[@version] ──────────────────
    ext_ns=$(echo "$id_info" | cut -d/ -f1)
    ext_name=$(echo "$id_info" | cut -d/ -f2)
    pinned_version=$(echo "$id_info" | cut -d/ -f3)

    if [ -n "$pinned_version" ]; then
      version="$pinned_version"
    else
      version=$(get_latest_release_version "$ext_ns" "$ext_name")
      if [ -z "$version" ]; then
        echo "WARN: No stable version found for $ext_ns.$ext_name, skipping"
        FAILED=$((FAILED + 1))
        continue
      fi
    fi

    # Try universal VSIX first; fall back to architecture-specific if configured.
    universal_url="$UPSTREAM_REGISTRY_URL/api/$ext_ns/$ext_name/$version/file/$ext_ns.$ext_name-$version.vsix"
    VSIX_PATH="$DOWNLOAD_DIR/$ext_ns.$ext_name-$version.vsix"

    echo "Downloading: $ext_ns.$ext_name $version"
    if ! curl -fsSL -o "$VSIX_PATH" "$universal_url" 2>/dev/null; then
      if [ -n "$ARCHITECTURE" ]; then
        platform_url="$UPSTREAM_REGISTRY_URL/api/$ext_ns/$ext_name/$ARCHITECTURE/$version/file/$ext_ns.$ext_name-$version@$ARCHITECTURE.vsix"
        VSIX_PATH="$DOWNLOAD_DIR/$ext_ns.$ext_name-$version@$ARCHITECTURE.vsix"
        echo "  Universal not found, trying $ARCHITECTURE"
        if ! curl -fsSL -o "$VSIX_PATH" "$platform_url"; then
          echo "WARN: Failed to download $ext_ns.$ext_name $version (tried universal and $ARCHITECTURE)"
          FAILED=$((FAILED + 1))
          continue
        fi
      else
        echo "WARN: Failed to download $ext_ns.$ext_name $version (no architecture set for fallback)"
        FAILED=$((FAILED + 1))
        continue
      fi
    fi

    resolve_dependencies "$ext_ns" "$ext_name"
  else
    # ── Legacy URL format ─────────────────────────────────────────────
    FILENAME=$(basename "$line")
    VSIX_PATH="$DOWNLOAD_DIR/$FILENAME"

    echo "Downloading: $line"
    if ! curl -fsSL -o "$VSIX_PATH" "$line"; then
      echo "WARN: Failed to download $line, skipping"
      FAILED=$((FAILED + 1))
      continue
    fi

    ext_id=$(parse_extension_id "$line") || true
    if [ -n "$ext_id" ]; then
      ext_ns=$(echo "$ext_id" | cut -d/ -f1)
      ext_name=$(echo "$ext_id" | cut -d/ -f2)
      resolve_dependencies "$ext_ns" "$ext_name"
    fi
  fi

  NAMESPACE=$(basename "$VSIX_PATH" | cut -d. -f1)
  if [ -n "$NAMESPACE" ]; then
    ovsx create-namespace "$NAMESPACE" --pat "$OVSX_PAT" 2>/dev/null || true
  fi

  FILENAME=$(basename "$VSIX_PATH")
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
