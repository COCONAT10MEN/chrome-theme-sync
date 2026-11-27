import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services
import "updater"

// Keeps Chrome, Chromium and Brave on Caelestia's colours. Whenever the scheme
// changes (new wallpaper, new scheme, light/dark), it hands the browser the
// matching colour through its theme policy, the same way stock Caelestia's CLI
// meant to, and pokes the browser so it switches right away.
//
// Costs nothing while idle: it reacts to the palette the shell already has,
// and only runs sync.sh when the colour actually changed.
Scope {
    id: root

    readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")).replace(/\/$/, "")

    Settings {
        id: settings

        category: "Plugin_chrome-theme-sync"
        property string colour: "Background"
    }

    function hex(c: color): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    // Colours.current, not Colours.palette: previews in Settings must not
    // repaint the browser.
    readonly property string target: {
        if (!Colours.schemeLoaded)
            return "";
        const p = Colours.current;
        return hex(settings.colour === "Accent" ? p.m3primary_paletteKeyColor : p.m3surface);
    }

    property string sent: ""
    property bool askedThisSession: false
    property bool warned: false

    onTargetChanged: settle.restart()
    Component.onCompleted: settle.restart()

    // A scheme switch updates the palette one colour at a time; wait for it
    // to settle so the browser gets one change, not a dozen.
    Timer {
        id: settle

        interval: 700
        onTriggered: root.sync()
    }

    function sync(): void {
        if (!root.target || root.target === root.sent)
            return;
        if (proc.running) {
            settle.restart();
            return;
        }
        const ask = !root.askedThisSession;
        root.askedThisSession = true;
        proc.colour = root.target;
        proc.command = ["bash", root.pluginDir + "/sync.sh", root.target].concat(ask ? ["ask"] : []);
        proc.running = true;
    }

    function handle(result: string): void {
        if (result === "changed" || result === "same" || result === "none") {
            root.sent = proc.colour;
            if (result === "changed")
                console.info("[chrome-theme-sync] browser colour set to " + proc.colour);
            // The scheme may have moved on while this ran.
            if (root.target !== root.sent)
                settle.restart();
            return;
        }
        console.warn("[chrome-theme-sync] " + result);
        if (root.warned)
            return;
        root.warned = true;
        if (result === "needs-setup")
            Toaster.toast(qsTr("Chrome colours"), qsTr("Needs a one-time admin OK to theme your browser. Turn the plugin off and on in Settings → Plugins to ask again."), "palette");
        else
            Toaster.toast(qsTr("Chrome colours"), qsTr("Couldn't update the browser colour. Will try again on the next scheme change."), "warning");
    }

    Process {
        id: proc

        property string colour

        stdout: StdioCollector {
            onStreamFinished: root.handle(text.trim())
        }
    }

    // Opt-in updates: asks before changing anything (see updater/update.sh).
    Updater {
        pluginDir: root.pluginDir
    }
}
