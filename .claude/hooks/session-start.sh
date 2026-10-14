#!/bin/bash
# Prepare REA for Claude Code cloud sessions: install the pinned package,
# install its bundled skill and fetch the pinned JADX engine JAR.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REA_VERSION="6.4.0"
JADX_JAR_URL="https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar"
JADX_JAR_SHA256="6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"
JADX_JAR="$HOME/.local/share/rea/android/jadx-headless-mcp-0.7.1-all.jar"
GHIDRA_ZIP_URL="https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip"
GHIDRA_ZIP_SHA256="ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db"
GHIDRA_ROOT="$HOME/.local/share/rea/ghidra"
GHIDRA_DIR="$GHIDRA_ROOT/ghidra_12.1.4_PUBLIC"

# Install the pinned package in its own prefix. This checkout is also named
# rea-agents, so npx inside it would resolve the unbuilt source package.
REA_PREFIX="$HOME/.local/share/rea/package"
package_dir="$REA_PREFIX/node_modules/rea-agents"
if [ "$(node -p "require('$package_dir/package.json').version" 2>/dev/null)" != "$REA_VERSION" ]; then
  npm install --prefix "$REA_PREFIX" --no-save --no-audit --no-fund "rea-agents@$REA_VERSION"
fi

# Install the bundled skill for Claude Code.
mkdir -p "$HOME/.claude/skills"
rm -rf "$HOME/.claude/skills/reverse-engineer-anything"
cp -R "$package_dir/skills/reverse-engineer-anything" "$HOME/.claude/skills/"

# Fetch, verify and extract Ghidra for native binary analysis. It uses the
# container's JDK 21.
if [ ! -x "$GHIDRA_DIR/support/analyzeHeadless" ]; then
  mkdir -p "$GHIDRA_ROOT"
  zip="$(mktemp "$GHIDRA_ROOT/ghidra.XXXXXX.zip")"
  staging="$(mktemp -d "$GHIDRA_ROOT/staging.XXXXXX")"
  if curl -fsSL -o "$zip" "$GHIDRA_ZIP_URL" &&
    echo "$GHIDRA_ZIP_SHA256  $zip" | sha256sum -c - >/dev/null &&
    unzip -q "$zip" -d "$staging" &&
    [ -x "$staging/ghidra_12.1.4_PUBLIC/support/analyzeHeadless" ]; then
    rm -rf "$GHIDRA_DIR"
    mv "$staging/ghidra_12.1.4_PUBLIC" "$GHIDRA_DIR"
  else
    echo "REA: Ghidra download or verification failed; native decompilation is unavailable." >&2
  fi
  rm -rf "$zip" "$staging"
fi

# Fetch and verify the JADX engine used for Android APK analysis.
if ! echo "$JADX_JAR_SHA256  $JADX_JAR" | sha256sum -c - >/dev/null 2>&1; then
  mkdir -p "$(dirname "$JADX_JAR")"
  tmp="$(mktemp "$JADX_JAR.XXXXXX")"
  if curl -fsSL -o "$tmp" "$JADX_JAR_URL" &&
    echo "$JADX_JAR_SHA256  $tmp" | sha256sum -c - >/dev/null; then
    mv "$tmp" "$JADX_JAR"
  else
    rm -f "$tmp"
    echo "REA: JADX JAR download or verification failed; APK analysis is unavailable." >&2
  fi
fi
