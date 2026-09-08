#!/bin/sh
# sudo askpass helper: asks for the administrator password in a macOS dialog.
#
# Used by run_sudo (tools/tools.sh) when the scripts run without a terminal, for
# example when they are driven by an AI agent. sudo passes its prompt as the first
# argument, the password is printed on stdout and read by sudo through a pipe: it
# is never written to disk nor logged. Cancelling the dialog makes sudo fail.

prompt=${1:-"Administrator password required"}
# Escape backslashes and double quotes for the AppleScript string literal
prompt=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')

osascript \
    -e "display dialog \"$prompt\" with title \"PrestaShop install tools\" default answer \"\" with hidden answer buttons {\"Cancel\", \"OK\"} default button \"OK\" with icon caution" \
    -e 'text returned of result'
