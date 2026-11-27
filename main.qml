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
    readonly property string glyphPath: "M479.8 72.6Q396.3 72.6 322 104.7Q247.7 136.8 192.1 192.4Q136.5 247.9 104.5 322.2Q72.5 396.5 72.5 480Q72.5 565.8 104.9 640.1Q137.3 714.4 193.9 769.4Q250.5 824.5 326.2 856Q401.9 887.6 488.4 887.6Q568.9 887.6 641.4 860.5Q713.8 833.4 768.6 785.4Q823.3 737.3 855.6 671.3Q887.9 605.4 887.9 527.3Q887.9 417.1 824 351.9Q760 286.8 653.4 286.8H583.5Q566.1 286.8 553.5 273.2Q540.8 259.5 540.8 242.9Q540.8 222 554 206.2Q567.2 190.3 567.2 166.3Q567.2 135.7 541.1 104.1Q514.9 72.6 479.8 72.6ZM480.3 144.9Q341.3 144.9 243.2 242.9Q145 341 145 480Q145 620.7 245.2 717.9Q345.4 815.1 488.9 815.1Q618.9 815.1 716.9 734.6Q815 654.2 815 525Q815 441.7 768.1 398.6Q721.1 355.5 647.5 355.5H575.5Q530.4 355.5 500.7 323Q471.1 290.6 471.1 245.7Q471.1 205.4 485.7 191.5Q500.3 177.5 500.3 163.7Q500.3 153.5 496 149.2Q491.7 144.9 480.3 144.9ZM248.8 453.5Q269 453.5 284.2 468.6Q299.3 483.7 299.3 504Q299.3 524.3 284.2 539.4Q269 554.5 248.8 554.5Q228.5 554.5 213.4 539.4Q198.3 524.3 198.3 504Q198.3 483.7 213.4 468.6Q228.5 453.5 248.8 453.5ZM373.8 622Q394.1 622 409.3 637.1Q424.5 652.2 424.5 672.5Q424.5 693 409.3 708Q394.1 723 374 723Q353.4 723 338.4 708Q323.4 693 323.4 672.6Q323.4 652.2 338.4 637.1Q353.4 622 373.8 622ZM585.8 622Q606.1 622 621.3 637.1Q636.5 652.2 636.5 672.5Q636.5 693 621.3 708Q606.1 723 586 723Q565.4 723 550.4 708Q535.4 693 535.4 672.6Q535.4 652.2 550.4 637.1Q565.4 622 585.8 622ZM715.5 453.5Q735.7 453.5 750.8 468.6Q766 483.7 766 504Q766 524.3 750.8 539.4Q735.7 554.5 715.5 554.5Q694.9 554.5 679.9 539.4Q665 524.3 665 504Q665 483.7 680 468.6Q695 453.5 715.5 453.5ZM478.7 141.9Q489.9 141.9 493.9 145.8Q497.9 149.7 497.9 160.1Q497.9 174.1 483.3 185.4Q468.7 196.7 468.7 237.1Q468.7 284 499.4 320Q530.1 356.1 576.9 356.1H653.4Q728.6 356.1 773.5 400.2Q818.4 444.4 818.4 525.9Q818.4 658.2 718.5 738.1Q618.6 818.1 488.5 818.1Q343.3 818.1 242.5 720Q141.7 621.9 141.7 479.9Q141.7 339.5 240.3 240.7Q338.9 141.9 478.7 141.9Z"

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
