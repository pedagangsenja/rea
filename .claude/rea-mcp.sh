#!/bin/bash
# Launch the pinned REA MCP server. In Claude Code cloud sessions, also point
# REA at the preinstalled Chromium and the Ghidra and JADX installations fetched
# by session-start.sh.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  if [ -x /opt/pw-browsers/chromium ]; then
    export REA_BROWSER_EXECUTABLE=/opt/pw-browsers/chromium
    # Cloud containers run as root, where Chromium's sandbox cannot start.
    export REA_BROWSER_NO_SANDBOX=true
  fi
  ghidra="$HOME/.local/share/rea/ghidra/ghidra_12.1.4_PUBLIC"
  if [ -x "$ghidra/support/analyzeHeadless" ]; then
    export GHIDRA_INSTALL_DIR="$ghidra"
  fi
  jar="$HOME/.local/share/rea/android/jadx-headless-mcp-0.7.1-all.jar"
  if [ -f "$jar" ]; then
    export REA_JADX_MCP_JAR="$jar"
  fi
fi

# session-start.sh installs the pinned package in cloud sessions. Elsewhere,
# run npx outside this checkout, whose own package is also named rea-agents.
rea="$HOME/.local/share/rea/package/node_modules/.bin/rea"
if [ -x "$rea" ]; then
  exec "$rea" mcp
fi
cd "$HOME"
exec npx -y rea-agents@6.4.0 mcp
