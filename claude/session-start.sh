#!/bin/sh
# Claude Code SessionStart hook: when a session opens inside a local PrestaShop instance
# (${baseFolder}<suffix> from config.yml), print the ps-infos report so that it lands in
# the agent context. Silent (exit 0) anywhere else.
#
# Hook input is JSON on stdin ({"cwd": "...", ...}), $PWD is used as a fallback.
# Wire it in ~/.claude/settings.json (see README.md), or run mac-config install/17-prestashop-claude.sh.

TOOLS_DIR=$(cd "$(dirname "$0")/.." && pwd)

# Never trigger the interactive config setup from a hook
if [ ! -f "$TOOLS_DIR/config.yml" ]; then
    exit 0
fi

cwd=""
if command -v jq > /dev/null 2>&1; then
    cwd=$(jq -r '.cwd // empty' 2>/dev/null)
fi
if [ -z "$cwd" ]; then
    cwd=$PWD
fi

# ps-infos detects the suffix from the working directory and fails outside an instance folder
report=$(cd "$cwd" 2>/dev/null && "$TOOLS_DIR/ps-infos.sh" 2>/dev/null < /dev/null) || exit 0

echo "PrestaShop instance detected from the working directory (ps-infos):"
echo "$report"
