#!/bin/sh
#
# Update extensions in the internal OpenVSX registry to their latest versions.
#
# Reads an extensions file (same format as publish-extensions.sh) where each line
# is a URL to a .vsix file. For each extension:
#   1. Parses the extension ID (namespace/name) from the .vsix URL
#   2. Queries the internal registry for the currently installed version
#   3. Queries the upstream open-vsx.org for the latest stable (non-pre-release) version
#   4. If VSCODE_ENGINE_VERSION is set, checks engine compatibility
#   5. Downloads and publishes the newer version if one is available
#
# Extensions that are not yet installed in the internal registry are skipped —
# use publish-extensions.sh for initial publishing.
#
# Required environment variables:
#   OVSX_REGISTRY_URL   - Internal OpenVSX server URL (e.g. http://openvsx-server:8080/openvsx)
#   OVSX_PAT            - Personal Access Token for publishing
#
# Optional environment variables:
#   VSCODE_ENGINE_VERSION - VS Code engine version for compatibility filtering (e.g. "1.92.0").
#                           When set, only extensions whose engines.vscode constraint is satisfied
#                           by this version will be updated. When unset, the latest non-pre-release
#                           version is used regardless of engine compatibility.
#   EXCLUDE_EXTENSIONS    - Comma-separated list of "namespace.name" extension IDs to skip
#                           (e.g., "redhat.java,redhat.vscode-xml").
#   UPSTREAM_REGISTRY_URL  - Upstream registry URL (default: https://open-vsx.org)
#   OVSX_FORWARDED_HOST    - External hostname for X-Forwarded-Host header (fixes cached API URLs)
#   OVSX_FORWARDED_PROTO   - External scheme for X-Forwarded-Proto header (default: https)
#   NODE_EXTRA_CA_CERTS    - Path to CA bundle for self-signed certificates
#
# Usage:
#   update-extensions.sh <extensions-file>
#

EXTENSIONS_FILE="${1:?Usage: update-extensions.sh <extensions-file>}"
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
UPDATED=0
SKIPPED=0
FAILED=0

# ──────────────────────────────────────────────────────────────────────
# parse_extension_id <vsix-url>
#
# Extracts "namespace/name" from a .vsix URL.
#
# Handles two URL patterns:
#   open-vsx.org API URL: https://open-vsx.org/api/{ns}/{name}/{ver}/file/{file}.vsix
#   direct file URL:      https://example.com/path/{ns}.{name}-{ver}.vsix
#
# The open-vsx.org pattern is tried first because it's unambiguous.
# The filename pattern relies on the convention: {namespace}.{name}-{version}.vsix
# where version starts with a digit.
# ──────────────────────────────────────────────────────────────────────
parse_extension_id() {
  url="$1"

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
# get_installed_version <namespace> <name>
#
# Queries the internal registry for the currently installed version.
# Prints the version string, or empty if the extension is not found.
# ──────────────────────────────────────────────────────────────────────
get_installed_version() {
  response=$(curl -fsSL $FORWARDED_HEADERS "$OVSX_REGISTRY_URL/api/$1/$2" 2>/dev/null) || return 0
  echo "$response" | jq -r '.version // empty'
}

# ──────────────────────────────────────────────────────────────────────
# get_latest_release_version <namespace> <name>
#
# Finds the latest non-pre-release version from the upstream registry.
#
# The default /api/{ns}/{name} endpoint returns the latest version overall,
# which may be a pre-release. To find the latest stable release:
#   1. Fetch the paginated version list (newest first)
#   2. For each version, query the API to check the preRelease flag
#   3. Return the first version where preRelease is false
#
# Prints the version string, or empty if no release version exists.
# ──────────────────────────────────────────────────────────────────────
get_latest_release_version() {
  ns="$1"
  ext="$2"
  page_size=20
  offset=0

  # First, check the default (latest) version — if it's not a pre-release, we're done.
  # Most extensions don't publish pre-releases, so this fast path avoids extra API calls.
  latest_response=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$ns/$ext" 2>/dev/null) || return 0
  is_pre=$(echo "$latest_response" | jq -r '.preRelease // false')
  if [ "$is_pre" != "true" ]; then
    echo "$latest_response" | jq -r '.version // empty'
    return 0
  fi

  # The latest version is a pre-release — walk through versions newest-first to find the
  # latest stable release. We limit the search to MAX_VERSIONS_TO_CHECK versions to avoid
  # excessive API calls for extensions that have many pre-release builds.
  max_check="${MAX_VERSIONS_TO_CHECK:-50}"
  checked=0

  while [ "$checked" -lt "$max_check" ]; do
    page=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$ns/$ext/versions?size=$page_size&offset=$offset" 2>/dev/null) || return 0
    total_size=$(echo "$page" | jq -r '.totalSize // 0')
    versions=$(echo "$page" | jq -r '.versions | keys[]' 2>/dev/null)

    if [ -z "$versions" ]; then
      return 0
    fi

    # Sort versions descending (newest first) and check each
    for ver in $(echo "$versions" | sort -rV); do
      checked=$((checked + 1))
      if [ "$checked" -gt "$max_check" ]; then
        echo "    (searched $max_check versions without finding a release)" >&2
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
# check_engine_compatibility <namespace> <name> <version>
#
# Checks whether a specific extension version is compatible with
# VSCODE_ENGINE_VERSION. Queries the upstream registry for the version's
# engines.vscode constraint and uses Node.js semver to evaluate it.
#
# Returns 0 if compatible (or if VSCODE_ENGINE_VERSION is unset), 1 otherwise.
# ──────────────────────────────────────────────────────────────────────
check_engine_compatibility() {
  # If no engine version filter is set, everything is compatible
  if [ -z "$VSCODE_ENGINE_VERSION" ]; then
    return 0
  fi

  response=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$1/$2/$3" 2>/dev/null) || return 1
  engine_constraint=$(echo "$response" | jq -r '.engines.vscode // empty')

  if [ -z "$engine_constraint" ]; then
    # No engine constraint declared — treat as compatible
    return 0
  fi

  # Use Node.js semver to check if VSCODE_ENGINE_VERSION satisfies the constraint.
  # The semver module is available as a transitive dependency of the ovsx CLI.
  node -e "
    try {
      const semver = require('semver');
      const ok = semver.satisfies('$VSCODE_ENGINE_VERSION', '$engine_constraint');
      process.exit(ok ? 0 : 1);
    } catch (e) {
      // semver not available — fall back to no filtering
      process.exit(0);
    }
  "
}

# ──────────────────────────────────────────────────────────────────────
# is_newer <upstream_version> <installed_version>
#
# Returns 0 if upstream_version is strictly newer than installed_version.
# Uses sort -V (version sort) for reliable semver-aware comparison.
# ──────────────────────────────────────────────────────────────────────
is_newer() {
  if [ "$1" = "$2" ]; then
    return 1
  fi
  # sort -V puts the smaller version first; if $1 comes second, it's newer
  oldest=$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)
  [ "$oldest" = "$2" ]
}

# ──────────────────────────────────────────────────────────────────────
# is_excluded <namespace.name>
#
# Checks whether an extension is in the EXCLUDE_EXTENSIONS list.
# EXCLUDE_EXTENSIONS is a comma-separated list of "namespace.name" entries.
# Returns 0 if excluded, 1 otherwise.
# ──────────────────────────────────────────────────────────────────────
is_excluded() {
  if [ -z "$EXCLUDE_EXTENSIONS" ]; then
    return 1
  fi

  ext_id="$1"
  # Use case statement with comma-delimited list for simple substring match.
  # Wrap the list in commas so each entry is bounded on both sides.
  case ",$EXCLUDE_EXTENSIONS," in
    *",$ext_id,"*) return 0 ;;
  esac

  return 1
}

# ──────────────────────────────────────────────────────────────────────
# Main loop — process each extension in the list
# ──────────────────────────────────────────────────────────────────────
echo "=== Extension update started ==="
echo "Internal registry: $OVSX_REGISTRY_URL"
echo "Upstream registry: $UPSTREAM_REGISTRY_URL"
if [ -n "$VSCODE_ENGINE_VERSION" ]; then
  echo "VS Code engine filter: $VSCODE_ENGINE_VERSION"
fi
if [ -n "$EXCLUDE_EXTENSIONS" ]; then
  echo "Excluded extensions: $EXCLUDE_EXTENSIONS"
fi
echo ""

while IFS= read -r line || [ -n "$line" ]; do
  # Skip empty lines and comments
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$line" in
    ""|\#*) continue ;;
  esac

  TOTAL=$((TOTAL + 1))

  # Step 1: Parse extension ID from the VSIX URL
  ext_id=$(parse_extension_id "$line") || true
  if [ -z "$ext_id" ]; then
    echo "WARN: Could not parse extension ID from: $line"
    FAILED=$((FAILED + 1))
    continue
  fi

  namespace=$(echo "$ext_id" | cut -d/ -f1)
  name=$(echo "$ext_id" | cut -d/ -f2)

  # Step 2: Check if the extension is excluded from auto-update
  if is_excluded "$namespace.$name"; then
    echo "--- Skipping $namespace.$name (excluded)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "--- Checking $namespace/$name"

  # Step 3: Get the currently installed version from the internal registry
  installed=$(get_installed_version "$namespace" "$name")
  if [ -z "$installed" ]; then
    echo "  Not installed in internal registry, skipping (use publish-extensions.sh first)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  echo "  Installed: $installed"

  # Step 4: Get the latest stable (non-pre-release) version from the upstream registry
  upstream=$(get_latest_release_version "$namespace" "$name")
  if [ -z "$upstream" ]; then
    echo "  WARN: No stable (non-pre-release) version found upstream, skipping"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  echo "  Upstream:  $upstream"

  # Step 5: Compare versions — skip if already up to date
  if ! is_newer "$upstream" "$installed"; then
    echo "  Already up to date"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Step 6: Check VS Code engine compatibility (only if VSCODE_ENGINE_VERSION is set)
  if ! check_engine_compatibility "$namespace" "$name" "$upstream"; then
    echo "  WARN: Version $upstream is not compatible with VS Code engine $VSCODE_ENGINE_VERSION, skipping"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Step 7: Download the newer .vsix from the upstream registry
  download_url="$UPSTREAM_REGISTRY_URL/api/$namespace/$name/$upstream/file/$namespace.$name-$upstream.vsix"
  vsix_path="$DOWNLOAD_DIR/$namespace.$name-$upstream.vsix"

  echo "  Downloading: $download_url"
  if ! curl -fsSL -o "$vsix_path" "$download_url"; then
    echo "  WARN: Failed to download $download_url"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Step 8: Publish the updated extension to the internal registry
  echo "  Publishing $namespace.$name $upstream (was $installed)"
  PUBLISH_OUTPUT=$(ovsx publish "$vsix_path" --pat "$OVSX_PAT" 2>&1) && PUBLISH_RC=0 || PUBLISH_RC=$?
  echo "  $PUBLISH_OUTPUT"
  if [ $PUBLISH_RC -eq 0 ]; then
    UPDATED=$((UPDATED + 1))
  else
    echo "  WARN: Failed to publish $namespace.$name $upstream"
    FAILED=$((FAILED + 1))
  fi

  rm -f "$vsix_path"
done < "$EXTENSIONS_FILE"

# ──────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Extension update complete ==="
echo "Total: $TOTAL, Updated: $UPDATED, Skipped: $SKIPPED, Failed: $FAILED"

# Exit with error only if every extension failed — indicates a systemic problem
# (e.g., expired token, network outage). Partial failures are logged but don't
# mark the Job as failed.
PROCESSED=$((UPDATED + SKIPPED))
if [ "$TOTAL" -gt 0 ] && [ "$PROCESSED" -eq 0 ]; then
  echo "ERROR: All extensions failed to update"
  exit 1
fi
