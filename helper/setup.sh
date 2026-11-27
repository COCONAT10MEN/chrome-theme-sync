#!/bin/sh
# One-time root setup for chrome-theme-sync. Run as root (sync.sh does it with
# sudo or pkexec, so you get a normal password prompt if one is needed).
#
#   setup.sh install <user>   copy the helper to /usr/local/libexec and let <user> run it
#   setup.sh uninstall        remove the helper, the sudo rule and Chrome's colour policy
set -eu
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HERE=$(cd "$(dirname "$0")" && pwd)
HELPER=/usr/local/libexec/caelestia-chrome-theme
SUDOERS=/etc/sudoers.d/caelestia-chrome-theme

[ "$(id -u)" = 0 ] || { echo "run this as root" >&2; exit 1; }

case "${1:-}" in
    install)
        user="${2:-}"
        printf '%s\n' "$user" | grep -Eqx '[a-z_][a-z0-9_.-]*\$?' || { echo "bad user name" >&2; exit 2; }
        id -u "$user" >/dev/null

        mkdir -p /usr/local/libexec
        tmp=$(mktemp /usr/local/libexec/.caelestia-chrome-theme.XXXXXX)
        cat "$HERE/caelestia-chrome-theme" > "$tmp"
        chown root:root "$tmp"
        chmod 755 "$tmp"
        mv -f "$tmp" "$HELPER"

        tmp=$(mktemp /etc/sudoers.d/.caelestia-chrome-theme.XXXXXX)
        printf '# chrome-theme-sync: lets %s update the browser colour policy\n%s ALL=(root) NOPASSWD: %s\n' "$user" "$user" "$HELPER" > "$tmp"
        chmod 440 "$tmp"
        if ! visudo -cf "$tmp" >/dev/null; then
            rm -f "$tmp"
            echo "sudo rule failed to validate" >&2
            exit 1
        fi
        mv -f "$tmp" "$SUDOERS"
        echo installed
        ;;
    uninstall)
        if [ -x "$HELPER" ]; then
            "$HELPER" clear
        else
            sh "$HERE/caelestia-chrome-theme" clear
        fi
        rm -f "$HELPER" "$SUDOERS"
        echo removed
        ;;
    *)
        echo "usage: $0 install <user> | uninstall" >&2
        exit 2
        ;;
esac
