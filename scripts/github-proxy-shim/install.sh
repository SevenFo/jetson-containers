#!/usr/bin/env bash
# Install lightweight GitHub proxy shim wrappers for curl/wget/git inside the image.
# This redirects GitHub-related traffic through GITHUB_PROXY / GITHUB_PROXY_RAW.
# Safe to run multiple times; it will overwrite existing shims.

set -euo pipefail

: "${GITHUB_PROXY:=}"
: "${GITHUB_PROXY_RAW:=${GITHUB_PROXY}}"

SHIM_DIR="/opt/ghproxy-shim"
mkdir -p "$SHIM_DIR"

# curl shim
cat >"$SHIM_DIR/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
normalize(){ local u="$1"; [[ "$u" == http://* ]] && u="https://${u:7}"; echo "$u"; }
rewrite(){ local u="$1"; 
  if [[ "$u" =~ ^https://github.com/([^/]+)/([^/]+)/blob/([^/]+)/(.*)$ ]]; then 
    u="https://raw.githubusercontent.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/${BASH_REMATCH[3]}/${BASH_REMATCH[4]}"; 
  fi
  case "$u" in
    http://raw.githubusercontent.com/*|https://raw.githubusercontent.com/*) echo "${GITHUB_PROXY_RAW}$(normalize "$u")";;
    http://gist.githubusercontent.com/*|https://gist.githubusercontent.com/*) echo "${GITHUB_PROXY_RAW}$(normalize "$u")";;
    http://github.com/*|https://github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://codeload.github.com/*|https://codeload.github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://objects.githubusercontent.com/*|https://objects.githubusercontent.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://api.github.com/*|https://api.github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    *) echo "$u";;
  esac
}
args=()
for a in "$@"; do
  if [[ "$a" == http*github.com* || "$a" == http*raw.githubusercontent.com* || "$a" == http*gist.githubusercontent.com* || "$a" == http*api.github.com* || "$a" == http*codeload.github.com* || "$a" == http*objects.githubusercontent.com* ]]; then
    a="$(rewrite "$a")"
  fi
  args+=("$a")
done
exec /usr/bin/curl "${args[@]}"
EOF
chmod +x "$SHIM_DIR/curl"

# wget shim
cat >"$SHIM_DIR/wget" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
normalize(){ local u="$1"; [[ "$u" == http://* ]] && u="https://${u:7}"; echo "$u"; }
rewrite(){ local u="$1"; 
  if [[ "$u" =~ ^https://github.com/([^/]+)/([^/]+)/blob/([^/]+)/(.*)$ ]]; then 
    u="https://raw.githubusercontent.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/${BASH_REMATCH[3]}/${BASH_REMATCH[4]}"; 
  fi
  case "$u" in
    http://raw.githubusercontent.com/*|https://raw.githubusercontent.com/*) echo "${GITHUB_PROXY_RAW}$(normalize "$u")";;
    http://gist.githubusercontent.com/*|https://gist.githubusercontent.com/*) echo "${GITHUB_PROXY_RAW}$(normalize "$u")";;
    http://github.com/*|https://github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://codeload.github.com/*|https://codeload.github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://objects.githubusercontent.com/*|https://objects.githubusercontent.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://api.github.com/*|https://api.github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    *) echo "$u";;
  esac
}
args=()
for a in "$@"; do
  if [[ "$a" == http*github.com* || "$a" == http*raw.githubusercontent.com* || "$a" == http*gist.githubusercontent.com* || "$a" == http*api.github.com* || "$a" == http*codeload.github.com* || "$a" == http*objects.githubusercontent.com* ]]; then
    a="$(rewrite "$a")"
  fi
  args+=("$a")
done
exec /usr/bin/wget "${args[@]}"
EOF
chmod +x "$SHIM_DIR/wget"

# git shim (clone-time URL rewrite)
cat >"$SHIM_DIR/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
normalize(){ local u="$1"; [[ "$u" == http://* ]] && u="https://${u:7}"; echo "$u"; }
convert(){ local u="$1";
  case "$u" in
    git@github.com:*) u="https://github.com/${u#git@github.com:}";;
    ssh://git@github.com/*) u="https://github.com/${u#ssh://git@github.com/}";;
    git://github.com/*) u="https://github.com/${u#git://github.com/}";;
  esac
  case "$u" in
    http://github.com/*|https://github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://codeload.github.com/*|https://codeload.github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://objects.githubusercontent.com/*|https://objects.githubusercontent.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    http://api.github.com/*|https://api.github.com/*) echo "${GITHUB_PROXY}$(normalize "$u")";;
    *) echo "$u";;
  esac
}
if [[ "${1:-}" == "clone" ]]; then
  newargs=()
  for a in "$@"; do
    if [[ "$a" == git@github.com:* || "$a" == ssh://git@github.com/* || "$a" == git://github.com/* || "$a" == http://github.com/* || "$a" == https://github.com/* || "$a" == http://codeload.github.com/* || "$a" == https://codeload.github.com/* ]]; then
      a="$(convert "$a")"
    fi
    newargs+=("$a")
  done
  exec /usr/bin/git "${newargs[@]}"
else
  exec /usr/bin/git "$@"
fi
EOF
chmod +x "$SHIM_DIR/git"

# print summary
ls -l "$SHIM_DIR" >&2
