#!/bin/sh
#
# Patches index.html for serving under a base path (e.g. /openvsx).
#
# The upstream WebUI is built with Vite base='/' so all asset references
# and API calls assume root. This script:
#   1. Rewrites asset src/href in HTML, adds a favicon link, and patches
#      static-asset paths in JS bundles (e.g. '/default-icon.png')
#   2. Injects a <script> that strips/restores the URL around React Router
#      init and popstate, intercepts fetch(), and wraps history APIs so
#      the SPA works transparently under the subpath
#
# Usage: patch-base-path.sh <base-path> <index-html-path>
#   e.g.: patch-base-path.sh /openvsx BOOT-INF/classes/static/index.html

BASE_PATH="$1"
INDEX_HTML="$2"

if [ -z "${BASE_PATH}" ] || [ ! -f "${INDEX_HTML}" ]; then
  echo "patch-base-path.sh: skipping (no base path or index.html not found)"
  exit 0
fi

echo "Patching ${INDEX_HTML} for base path: ${BASE_PATH}"

# Step 1: Rewrite asset references from root to base path.
# Only matches src="/ and href="/ (local absolute paths).
# External URLs like href="https://..." are unaffected.
sed -i \
  -e "s|src=\"/|src=\"${BASE_PATH}/|g" \
  -e "s|href=\"/|href=\"${BASE_PATH}/|g" \
  "${INDEX_HTML}"

# Step 1b: Add explicit favicon link (browsers auto-request /favicon.ico
# at root when no <link rel="icon"> exists) and rewrite static asset
# references inside JS bundles (e.g. '/default-icon.png' used as <img src>).
sed -i "/<head>/a\\
<link rel=\"icon\" href=\"${BASE_PATH}/favicon.ico\">" "${INDEX_HTML}"

STATIC_DIR=$(dirname "${INDEX_HTML}")
for f in "${STATIC_DIR}"/*.js "${STATIC_DIR}"/assets/*.js; do
  [ -f "$f" ] || continue
  sed -i "s|/default-icon.png|${BASE_PATH}/default-icon.png|g" "$f"
done

# Step 2: Inject interceptor script after <head>.
# This script runs before the main SPA bundle and:
#   a) Saves native history methods
#   b) Strips the base path via replaceState so React Router matches routes
#   c) Restores the URL after React mounts (replaceState does not fire
#      popstate, so React Router keeps using the stripped internal state)
#   d) Handles back/forward by temporarily stripping before React Router
#      processes popstate, then restoring
#   e) Wraps fetch() to prepend the base path to same-origin requests
#   f) Wraps pushState/replaceState to add the base path to navigations
sed -i "/<head>/a\\
<script>\\
(function() {\\
  var B = '${BASE_PATH}';\\
\\
  // (a) Save native history methods before wrapping\\
  var nativePush = history.pushState.bind(history);\\
  var nativeRepl = history.replaceState.bind(history);\\
\\
  // (b) Strip base path so React Router sees root-relative paths on init\\
  var p = location.pathname;\\
  if (p.startsWith(B + '/') || p === B) {\\
    nativeRepl(history.state, '', (p.slice(B.length) || '/') + location.search + location.hash);\\
  }\\
\\
  // (c) After React mounts into #main, restore the base path in the URL.\\
  // replaceState does not fire popstate, so React Router will not re-read\\
  // location and keeps its stripped internal state.\\
  // Script runs in <head>, so #main does not exist yet — wait for DOM.\\
  document.addEventListener('DOMContentLoaded', function() {\\
    var mainEl = document.getElementById('main');\\
    if (mainEl) {\\
      new MutationObserver(function(_, obs) {\\
        obs.disconnect();\\
        var cur = location.pathname;\\
        if (!cur.startsWith(B)) {\\
          nativeRepl(history.state, '', B + cur + location.search + location.hash);\\
        }\\
      }).observe(mainEl, { childList: true });\\
    }\\
  });\\
\\
  // (d) Handle back/forward: temporarily strip the URL before React\\
  // Router processes the popstate event, then restore it.\\
  // This listener runs first because our inline script loads before modules.\\
  window.addEventListener('popstate', function() {\\
    var nav = location.pathname;\\
    if (nav.startsWith(B + '/') || nav === B) {\\
      nativeRepl(history.state, '', (nav.slice(B.length) || '/') + location.search + location.hash);\\
      setTimeout(function() {\\
        var c = location.pathname;\\
        if (!c.startsWith(B)) {\\
          nativeRepl(history.state, '', B + c + location.search + location.hash);\\
        }\\
      }, 0);\\
    }\\
  });\\
\\
  // (e) Intercept fetch: prepend base path to same-origin requests.\\
  // Handles absolute URLs, relative paths, Request objects, and URL objects.\\
  var origFetch = window.fetch.bind(window);\\
  function rewriteUrl(input) {\\
    if (typeof input === 'string') {\\
      if (input.startsWith('/') && !input.startsWith(B + '/') && input !== B) {\\
        return B + input;\\
      }\\
      if (input.startsWith(location.origin + '/') && !input.startsWith(location.origin + B + '/')) {\\
        return location.origin + B + input.slice(location.origin.length);\\
      }\\
    } else if (input instanceof Request) {\\
      var u = input.url;\\
      if (u.startsWith(location.origin + '/') && !u.startsWith(location.origin + B + '/')) {\\
        return new Request(location.origin + B + u.slice(location.origin.length), input);\\
      }\\
    } else if (input instanceof URL) {\\
      if (input.origin === location.origin && !input.pathname.startsWith(B + '/') && input.pathname !== B) {\\
        return new URL(B + input.pathname + input.search + input.hash, input.origin);\\
      }\\
    }\\
    return input;\\
  }\\
  window.fetch = function(input, opts) {\\
    input = rewriteUrl(input);\\
    return origFetch(input, opts);\\
  };\\
\\
  // (f) Wrap pushState/replaceState: pass the clean (unprefixed) URL so\\
  // React Router matches routes, then restore the prefix via replaceState\\
  // in a setTimeout (replaceState does not fire popstate so React Router\\
  // keeps its clean internal state). Same pattern as the popstate handler.\\
  function wrapNav(fn) {\\
    return function(state, title, url) {\\
      if (typeof url === 'string' && url.startsWith('/') && !url.startsWith(B + '/')) {\\
        fn.call(this, state, title, url);\\
        setTimeout(function() {\\
          var c = location.pathname;\\
          if (!c.startsWith(B)) {\\
            nativeRepl(history.state, '', B + c + location.search + location.hash);\\
          }\\
        }, 0);\\
        return;\\
      }\\
      return fn.call(this, state, title, url);\\
    };\\
  }\\
  history.pushState = wrapNav(nativePush);\\
  history.replaceState = wrapNav(nativeRepl);\\
})();\\
</script>" "${INDEX_HTML}"

echo "Patching complete."
