#!/bin/sh
#
# Test suite for publish-extensions.sh and update-extensions.sh logic.
# Tests parse_identifier, get_latest_release_version, and architecture fallback.
#
# Usage: ./test-scripts.sh
#

UPSTREAM_REGISTRY_URL="${UPSTREAM_REGISTRY_URL:-https://open-vsx.org}"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label — expected '$expected', got '$actual'"
  fi
}

assert_rc() {
  local label="$1" expected_rc="$2" actual_rc="$3"
  if [ "$expected_rc" = "$actual_rc" ]; then
    pass "$label (rc=$actual_rc)"
  else
    fail "$label — expected rc=$expected_rc, got rc=$actual_rc"
  fi
}

# ──────────────────────────────────────────────────────────────────────
# parse_identifier — inline copy of the function under test
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
# get_latest_release_version — inline copy of the function under test
# ──────────────────────────────────────────────────────────────────────
get_latest_release_version() {
  local ns="$1" ext="$2" page_size=20 offset=0
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
    [ -z "$versions" ] && return 0
    for ver in $(echo "$versions" | sort -rV); do
      checked=$((checked + 1))
      [ "$checked" -gt "$max_check" ] && return 0
      ver_response=$(curl -fsSL "$UPSTREAM_REGISTRY_URL/api/$ns/$ext/$ver" 2>/dev/null) || continue
      ver_pre=$(echo "$ver_response" | jq -r '.preRelease // false')
      if [ "$ver_pre" != "true" ]; then echo "$ver"; return 0; fi
    done
    offset=$((offset + page_size))
    [ "$offset" -ge "$total_size" ] && return 0
  done
}

# ──────────────────────────────────────────────────────────────────────
echo "=== parse_identifier ==="

out=$(parse_identifier "redhat.vscode-yaml")
assert_eq "simple identifier: namespace" "redhat" "$(echo "$out" | cut -d/ -f1)"
assert_eq "simple identifier: name"      "vscode-yaml" "$(echo "$out" | cut -d/ -f2)"
assert_eq "simple identifier: version"   "" "$(echo "$out" | cut -d/ -f3)"

out=$(parse_identifier "redhat.vscode-yaml@1.21.0")
assert_eq "pinned identifier: namespace" "redhat" "$(echo "$out" | cut -d/ -f1)"
assert_eq "pinned identifier: name"      "vscode-yaml" "$(echo "$out" | cut -d/ -f2)"
assert_eq "pinned identifier: version"   "1.21.0" "$(echo "$out" | cut -d/ -f3)"

out=$(parse_identifier "ms-python.python")
assert_eq "dashed namespace: namespace" "ms-python" "$(echo "$out" | cut -d/ -f1)"
assert_eq "dashed namespace: name"      "python" "$(echo "$out" | cut -d/ -f2)"

out=$(parse_identifier "ms-vscode.cpptools@1.17.5")
assert_eq "dashed ns + version: namespace" "ms-vscode" "$(echo "$out" | cut -d/ -f1)"
assert_eq "dashed ns + version: name"      "cpptools" "$(echo "$out" | cut -d/ -f2)"
assert_eq "dashed ns + version: version"   "1.17.5" "$(echo "$out" | cut -d/ -f3)"

parse_identifier "https://open-vsx.org/api/redhat/vscode-yaml/1.21.0/file/redhat.vscode-yaml-1.21.0.vsix"
assert_rc "URL returns rc=1" "1" "$?"

parse_identifier "https://example.com/some.extension-1.0.0.vsix"
assert_rc "arbitrary URL returns rc=1" "1" "$?"

# ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== architecture file reading ==="

TMPDIR=$(mktemp -d)
EXTENSIONS_FILE="$TMPDIR/extensions.list"
echo "redhat.vscode-yaml" > "$EXTENSIONS_FILE"
echo "linux-x64" > "$TMPDIR/architecture"

ARCHITECTURE_FILE="$(dirname "$EXTENSIONS_FILE")/architecture"
ARCH="${ARCHITECTURE:-$(cat "$ARCHITECTURE_FILE" 2>/dev/null | tr -d '[:space:]')}"
assert_eq "reads architecture from file" "linux-x64" "$ARCH"

rm -f "$TMPDIR/architecture"
ARCH="${ARCHITECTURE:-$(cat "$ARCHITECTURE_FILE" 2>/dev/null | tr -d '[:space:]')}"
assert_eq "returns empty when file absent" "" "$ARCH"

rm -rf "$TMPDIR"

# ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== get_latest_release_version (requires internet) ==="

ver=$(get_latest_release_version "redhat" "vscode-yaml")
if [ -n "$ver" ]; then
  pass "redhat.vscode-yaml: got version '$ver'"
else
  fail "redhat.vscode-yaml: no version returned"
fi

ver=$(get_latest_release_version "ms-python" "python")
if [ -n "$ver" ]; then
  pass "ms-python.python: got version '$ver'"
else
  fail "ms-python.python: no version returned"
fi

# ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== universal vs platform-specific VSIX (requires internet) ==="

# redhat.vscode-yaml should have a universal VSIX
yaml_ver=$(get_latest_release_version "redhat" "vscode-yaml")
if [ -n "$yaml_ver" ]; then
  url="$UPSTREAM_REGISTRY_URL/api/redhat/vscode-yaml/$yaml_ver/file/redhat.vscode-yaml-$yaml_ver.vsix"
  if curl -fsSLI -o /dev/null "$url" 2>/dev/null; then
    pass "redhat.vscode-yaml $yaml_ver: universal VSIX exists"
  else
    fail "redhat.vscode-yaml $yaml_ver: universal VSIX not found at $url"
  fi
else
  fail "redhat.vscode-yaml: could not resolve version for VSIX test"
fi

# ms-python.debugpy only ships platform-specific VSIXes (no universal .vsix)
# Use a known stable version that has linux-x64 builds
debugpy_ver="2025.14.0"
universal_url="$UPSTREAM_REGISTRY_URL/api/ms-python/debugpy/$debugpy_ver/file/ms-python.debugpy-$debugpy_ver.vsix"
if curl -fsSLI -o /dev/null "$universal_url" 2>/dev/null; then
  fail "ms-python.debugpy $debugpy_ver: universal VSIX found (architecture fallback not needed)"
else
  pass "ms-python.debugpy $debugpy_ver: no universal VSIX — architecture fallback would be used"
  # Correct URL format: /api/{ns}/{name}/{targetPlatform}/{version}/file/{ns}.{name}-{version}@{targetPlatform}.vsix
  platform_url="$UPSTREAM_REGISTRY_URL/api/ms-python/debugpy/linux-x64/$debugpy_ver/file/ms-python.debugpy-$debugpy_ver@linux-x64.vsix"
  if curl -fsSLI -o /dev/null "$platform_url" 2>/dev/null; then
    pass "ms-python.debugpy $debugpy_ver linux-x64: platform-specific VSIX exists"
  else
    fail "ms-python.debugpy $debugpy_ver linux-x64: platform-specific VSIX not found at $platform_url"
  fi
fi

# ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "Passed: $PASS, Failed: $FAIL"
[ "$FAIL" -eq 0 ]
