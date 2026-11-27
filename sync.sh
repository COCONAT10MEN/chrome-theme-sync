#!/usr/bin/env bash
# Sends a colour to Chrome/Chromium/Brave. Run by main.qml when the scheme changes.
#
#   sync.sh <#rrggbb> [ask]
#
# Prints one word for main.qml:
#   changed | same     the policy was written (or already right)
#   none               no supported browser installed
#   needs-setup        the one-time admin step hasn't been done (or was cancelled)
#   failed             something else went wrong
#
# "ask" lets it pop a password prompt (pkexec) for the one-time setup. main.qml
# only passes it on the first sync after the shell starts, so it never nags.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HELPER=/usr/local/libexec/caelestia-chrome-theme
COLOUR=${1:-}
ASK=${2:-}

[[ $COLOUR =~ ^#[0-9a-fA-F]{6}$ ]] || { echo failed; exit 0; }

want=$(sed -n 's/^VERSION=//p' "$HERE/helper/caelestia-chrome-theme")
have=$(sudo -n "$HELPER" version 2>/dev/null)

if [[ $have != "$want" ]]; then
    if sudo -n true 2>/dev/null; then
        sudo -n sh "$HERE/helper/setup.sh" install "$USER" >/dev/null 2>&1 || { echo failed; exit 0; }
    elif [[ $ASK == ask ]] && command -v pkexec >/dev/null; then
        pkexec sh "$HERE/helper/setup.sh" install "$USER" >/dev/null 2>&1 || { echo needs-setup; exit 0; }
    else
        echo needs-setup
        exit 0
    fi
fi

out=$(sudo -n "$HELPER" set "$COLOUR" 2>/dev/null) || { echo failed; exit 0; }

# Chrome only rereads policy files every now and then, so poke the running
# browsers to pick it up right away. Never start one that isn't running:
# --refresh-platform-policy would open a hidden browser instead. timeout is
# there in case it quits in between and that happens anyway. Chrome is called
# through its own launcher, not /usr/bin/google-chrome-stable, so a broken
# chrome-flags.conf can't open junk tabs.
if [[ $out == changed ]]; then
    if pgrep -f '^/opt/google/chrome/chrome( |$)' >/dev/null; then
        timeout 10 /opt/google/chrome/google-chrome --refresh-platform-policy --no-startup-window >/dev/null 2>&1 &
    fi
    if pgrep -x chromium >/dev/null && command -v chromium >/dev/null; then
        timeout 10 chromium --refresh-platform-policy --no-startup-window >/dev/null 2>&1 &
    fi
    if pgrep -x brave >/dev/null; then
        b=$(command -v brave || command -v brave-browser)
        [[ -n $b ]] && timeout 10 "$b" --refresh-platform-policy --no-startup-window >/dev/null 2>&1 &
    fi
    wait
fi

echo "$out"
