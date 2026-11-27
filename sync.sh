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
# browsers to pick it up right away.
#
# Each running browser gets poked through its own profile folder
# (--user-data-dir), because the poke only reaches the browser using the same
# folder. Without that, a Chrome started with its own folder never hears it,
# and the poke starts a hidden Chrome on the default folder instead. Browsers
# that aren't running are never started. timeout is there in case one quits in
# between. Chrome is called through its own launcher, not
# /usr/bin/google-chrome-stable, so a broken chrome-flags.conf can't open junk tabs.
#
#   refresh <main process regex> <launcher>
refresh() {
    local pattern=$1 launcher=$2 pid seen=$'\n' dir line rest cand best tail word
    local -a opts
    [[ -x $launcher ]] || launcher=$(command -v "$launcher") || return 0
    for pid in $(pgrep -f "$pattern"); do
        # Chrome rewrites its command line into one string joined by spaces.
        line=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || continue
        [[ $line == *" --type="* ]] && continue   # a helper process, not the browser
        dir="" opts=()
        if [[ $line == *" --user-data-dir="* ]]; then
            # The folder can have spaces in it: grow it a word at a time while
            # it's still a real folder. Can't tell which one? Leave it alone.
            rest=${line#*--user-data-dir=}
            cand=${rest%% *} best=""
            [[ -d $cand ]] && best=$cand
            tail=${rest#"$cand"}
            while [[ $tail == " "?* ]]; do
                word=${tail# } word=${word%% *}
                cand="$cand $word" tail=${tail# } tail=${tail#"$word"}
                [[ -d $cand ]] && best=$cand
            done
            [[ -n $best ]] || continue
            dir="--user-data-dir=$best"
        fi
        [[ $seen == *$'\n'"$dir"$'\n'* ]] && continue
        seen+="$dir"$'\n'
        [[ -n $dir ]] && opts=("$dir")
        timeout 10 "$launcher" "${opts[@]}" --refresh-platform-policy --no-startup-window >/dev/null 2>&1 &
    done
}

if [[ $out == changed ]]; then
    refresh '^/opt/google/chrome/chrome( |$)' /opt/google/chrome/google-chrome
    refresh '^/usr/lib/chromium/chromium( |$)' chromium
    refresh '^/opt/brave\.com/brave/brave( |$)' "$(command -v brave || command -v brave-browser || echo brave)"
    wait
fi

echo "$out"
