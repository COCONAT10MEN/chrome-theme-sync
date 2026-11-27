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
    Component.onCompleted: {
        settle.restart();
        iconFile.setText(iconSvg);
    }

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
            Toaster.toast(qsTr("Chrome colours"), qsTr("Setting the browser colour needs your password once. Turn the plugin off and on in Settings → Plugins to try again."), "palette");
        else
            Toaster.toast(qsTr("Chrome colours"), qsTr("Couldn't update the browser colour. It will try again next time the scheme changes."), "warning");
    }

    Process {
        id: proc

        property string colour

        stdout: StdioCollector {
            onStreamFinished: root.handle(text.trim())
        }
    }

    // Plugin icon for Settings -> Plugins. Settings draws font icons a couple of
    // pixels off centre, so this is an SVG of the Material Symbols glyph instead,
    // drawn in your current theme colours and redrawn when they change. It's
    // deleted while the plugin isn't running, so it can't go stale.
    readonly property string glyphPath: "M479.84 72.62Q396.26 72.62 321.99 104.73Q247.73 136.83 192.14 192.36Q136.55 247.89 104.5 322.21Q72.46 396.54 72.46 479.99Q72.46 565.82 104.9 640.09Q137.34 714.37 193.91 769.42Q250.49 824.47 326.21 856.05Q401.94 887.62 488.45 887.62Q568.9 887.62 641.35 860.52Q713.8 833.43 768.57 785.36Q823.33 737.29 855.62 671.33Q887.91 605.37 887.91 527.29Q887.91 417.06 823.97 351.92Q760.03 286.78 653.38 286.78H583.5Q566.1 286.78 553.45 273.16Q540.8 259.55 540.8 242.86Q540.8 222.04 554 206.19Q567.2 190.35 567.2 166.3Q567.2 135.65 541.06 104.14Q514.91 72.62 479.84 72.62ZM248.82 453.46Q268.99 453.46 284.17 468.59Q299.34 483.72 299.34 504Q299.34 524.29 284.16 539.41Q268.98 554.54 248.83 554.54Q228.52 554.54 213.4 539.41Q198.29 524.28 198.29 504Q198.29 483.71 213.4 468.59Q228.52 453.46 248.82 453.46ZM373.82 621.98Q394.13 621.98 409.31 637.09Q424.48 652.2 424.48 672.5Q424.48 693.04 409.31 708.03Q394.13 723.03 373.96 723.03Q353.42 723.03 338.42 708.03Q323.43 693.03 323.43 672.64Q323.43 652.2 338.43 637.09Q353.43 621.98 373.82 621.98ZM585.84 621.98Q606.14 621.98 621.31 637.09Q636.49 652.2 636.49 672.5Q636.49 693.04 621.31 708.03Q606.12 723.03 585.98 723.03Q565.42 723.03 550.43 708.03Q535.44 693.03 535.44 672.64Q535.44 652.2 550.43 637.09Q565.42 621.98 585.84 621.98ZM715.46 453.46Q735.65 453.46 750.83 468.59Q766.01 483.72 766.01 504Q766.01 524.29 750.83 539.41Q735.65 554.54 715.48 554.54Q694.94 554.54 679.95 539.41Q664.95 524.28 664.95 504Q664.95 483.71 679.95 468.59Q694.95 453.46 715.46 453.46Z"

    function iconHex(c: color): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    readonly property string iconSvg: '<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 48 48">'
        + '<path transform="translate(12.3681 35.6304) scale(0.024224 -0.024224)" fill="' + iconHex(Colours.palette.m3onSecondaryContainer) + '" d="' + glyphPath + '"/>'
        + '</svg>\n'

    onIconSvgChanged: iconFile.setText(iconSvg)
    Component.onDestruction: Quickshell.execDetached(["rm", "-f", root.pluginDir + "/icon.svg"])

    FileView {
        id: iconFile

        path: root.pluginDir + "/icon.svg"
        printErrors: false
    }

    // Opt-in updates: asks before changing anything (see updater/update.sh).
    Updater {
        pluginDir: root.pluginDir
    }
}
