//@ pragma IconTheme Papirus-Dark
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Polkit
import Quickshell.Services.Pam
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "Themes.js" as Themes

ShellRoot {

PanelWindow {
    id: root

    FileView {
        id: cfgFile
        path: Quickshell.env("PANACEA_SETTINGS") || (Quickshell.env("HOME") + "/.config/panacea/settings.json")
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            property string fontFam: "JetBrainsMono Nerd Font"
            property int    fontSize: 15
            property int    iconSize: 17
            property string colFg:    "#ffffff"
            property real   mutedAlpha: 0.45
            property string colOn:    "#3b82f6"
            property int    pillH:  38
            property string pillPos: "top"
            property bool   pillAutoHide: false
            property bool   pillOverlay: true
            property bool   pillKeepVisible: false
            property bool   closePanaceaFirst: true

            property string monOverrides: ""
            property string pillScreen: "auto"

            property bool   notchMode: true
            property int    notchFlare: 12
            property int    collapsedW: 260
            property int    expandedH: 620
            property int    islandGap: 12
            property int    islandRadius: 0

            property bool   clockSeconds: false
            property bool   clockWeekday: true
            property string clockTz: "auto"
            property string clockDateFmt: "d MMMM"

            property string themeId: "nothing"
            property string fontBody: "JetBrainsMono Nerd Font"
            property string fontDisplay: "JetBrainsMono Nerd Font"
            property int    spacingUnit: 8
            property int    smallRadius: 10

            property string vpnPreferredClient: ""
            property string vpnPreferred: ""
            property bool   mascotEnabled: true
            property bool   reduceMotion: false
            property int    animMove: 230
            property int    animFade: 200
            property int    animHover: 150
            property int    animBounce: 79

            property bool   notifDnd: false
            property int    notifTimeout: 5000
            property int    notifCritTimeout: 0
            property bool   notifPreview: true

            property int    lockBlur: 32
            property string lockHint: ""

            property string ccLayout: ""
            property bool   pillDrag: false
            property int    panelW: 540
            property string lang: "en"
            property bool   clock12: false
            property int    recFps: 60
            property string recDir: "~/Videos"
            property bool   recSysAudio: false
            property bool   recMic: false
            property string recMicDevice: ""
            property bool   vaultCapture: false
            property bool   filesWindow: false
            property bool   filesHidden: true
            property string filesMode: "list"

            property int    vibrance: 50

            property real   mouseSens: 0
            property bool   mouseRaw: false
            property string keyboardLayouts: "us"
            property string keyboardVariants: ""
            property string keyboardOptions: ""

            property bool   featLauncher: false
            property string searchEngine: "duckduckgo"
            property string agentEventFilter: "all"
            property string aiUrl: ""
            property string updNotifiedVer: ""
            property string aiKey: ""
            property string aiModel: ""
            property bool   featLaunchpad: false
            property bool   featPlayer: true
            property bool   featWifi: true
            property bool   featBluetooth: true
            property bool   featClipboard: true
            property bool   featNotifications: true
            property bool   featCalendar: true
            property bool   featThemes: false
            property bool   featRecord: true
            property bool   featFiles: false
            property bool   featMedia: true
            property bool   featVault: false
            property bool   featLock: true
            property bool   featAudio: true
            property bool   featPowerProfiles: true
            property bool   featOsd: true
            property bool   featPowermenu: true
            property bool   featPolkit: false

            property string weatherKey: ""
            property string weatherCity: ""
            property string weatherUnits: "metric"
            property bool   weatherOnIsland: false
            property bool   systemLoadOnIsland: false
            property bool   featWidgets: false
            property string widgetClockMode: "analog"
            property string widgetRightMode: "weather"
            property string widgetProgressMode: "day"
            property bool   widgetMusic: true
            property bool   widgetScratchpad: true
            property string keyboardLayoutMap: ""

            property real   termAlpha: 0.90

            property string bind_pillLauncher: "SUPER + A"
            property string bind_launchpad: "SUPER + G"
            property string bind_pillControls: "SUPER + Z"
            property string bind_pillSettings: "SUPER + I"
            property string bind_pillShortcuts: "SUPER + slash"
            property string bind_overview: "SUPER + Tab"
            property string bind_pillWifi: "SUPER + SHIFT + W"
            property string bind_pillBt: "SUPER + SHIFT + B"
            property string bind_pillClip: "SUPER + V"
            property string bind_pillPower: "CTRL + ALT + delete"
            property string bind_pillNotif: "SUPER + SHIFT + N"
            property string bind_pillRecord: "SUPER + P"
            property string bind_terminal: "SUPER + T"
            property string bind_terminalAlt: "SUPER + Return"
            property string bind_closeWindow: "SUPER + Q"
            property string bind_browser: "SUPER + F"
            property string bind_fullscreen: "SUPER + SHIFT + F"
            property string bind_exitHypr: "SUPER + SHIFT + M"
            property string bind_floatToggle: "SUPER + W"
            property string bind_pillVault: "SUPER + SHIFT + P"
            property string bind_voxDictate: "Alt_R"
            property string bind_floatCenter: "SUPER + SHIFT + Space"
            property string bind_fileManager: "SUPER + E"
            property string bind_fileManagerTui: "SUPER + SHIFT + E"
            property string bind_toggleSplit: "SUPER + J"
            property string bind_notes: "SUPER + O"
            property string bind_screenshot: "SUPER + SHIFT + S"
            property string bind_screenOff: "SUPER + SHIFT + F12"
            property string bind_packWorkspaces: "SUPER + SHIFT + A"
            property string bind_emptyWorkspace: "SUPER + Space"
            property string bind_specialWorkspace: "SUPER + S"
            property string bind_workspace1: "SUPER + 1"
            property string bind_workspace2: "SUPER + 2"
            property string bind_workspace3: "SUPER + 3"
            property string bind_workspace4: "SUPER + 4"
            property string bind_workspace5: "SUPER + 5"
            property string bind_workspace6: "SUPER + 6"
            property string bind_workspace7: "SUPER + 7"
            property string bind_workspace8: "SUPER + 8"
            property string bind_workspace9: "SUPER + 9"
            property string bind_workspace10: "SUPER + 0"
            property string bind_moveWorkspace1: "SUPER + SHIFT + 1"
            property string bind_moveWorkspace2: "SUPER + SHIFT + 2"
            property string bind_moveWorkspace3: "SUPER + SHIFT + 3"
            property string bind_moveWorkspace4: "SUPER + SHIFT + 4"
            property string bind_moveWorkspace5: "SUPER + SHIFT + 5"
            property string bind_moveWorkspace6: "SUPER + SHIFT + 6"
            property string bind_moveWorkspace7: "SUPER + SHIFT + 7"
            property string bind_moveWorkspace8: "SUPER + SHIFT + 8"
            property string bind_moveWorkspace9: "SUPER + SHIFT + 9"
            property string bind_moveWorkspace10: "SUPER + SHIFT + 0"
            property string bind_themeSwitch: "SUPER + SHIFT + T"
            property string bind_lockScreen: "SUPER + L"
            property string bind_closeMouse: "mouse:277"
            property string bind_focusLeft: "SUPER + left"
            property string bind_focusRight: "SUPER + right"
            property string bind_focusUp: "SUPER + up"
            property string bind_focusDown: "SUPER + down"
            property string bind_moveLeft: "SUPER + SHIFT + left"
            property string bind_moveRight: "SUPER + SHIFT + right"
            property string bind_moveUp: "SUPER + SHIFT + up"
            property string bind_moveDown: "SUPER + SHIFT + down"
            property string bind_resizeRight: "ALT + right"
            property string bind_resizeLeft: "ALT + left"
            property string bind_resizeUp: "ALT + up"
            property string bind_resizeDown: "ALT + down"
            property string bind_workspaceNext: "SUPER + mouse_down"
            property string bind_workspacePrevious: "SUPER + mouse_up"
            property string bind_dragWindow: "SUPER + mouse:272"
            property string bind_resizeWindowMouse: "SUPER + mouse:273"
            property string bind_micMute: "XF86AudioMicMute"
            property string bind_volumeUp: "XF86AudioRaiseVolume"
            property string bind_volumeDown: "XF86AudioLowerVolume"
            property string bind_volumeMute: "XF86AudioMute"
            property string bind_brightnessUp: "XF86MonBrightnessUp"
            property string bind_brightnessDown: "XF86MonBrightnessDown"
            property string bind_mediaNextAlt: "SUPER + XF86AudioRaiseVolume"
            property string bind_mediaPreviousAlt: "SUPER + XF86AudioLowerVolume"
            property string bind_mediaNext: "XF86AudioNext"
            property string bind_mediaPause: "XF86AudioPause"
            property string bind_mediaPlay: "XF86AudioPlay"
            property string bind_mediaPrevious: "XF86AudioPrev"
            property string bind_lidOn: "switch:on:Lid Switch"
            property string bind_lidOff: "switch:off:Lid Switch"
        }
    }
    readonly property var defaultBinds: ({
        pillLauncher: "SUPER + A",
        launchpad:    "SUPER + G",
        pillControls: "SUPER + Z",
        pillSettings: "SUPER + I",
        pillShortcuts: "SUPER + slash",
        overview:     "SUPER + Tab",
        pillWifi:     "SUPER + SHIFT + W",
        pillBt:       "SUPER + SHIFT + B",
        pillClip:     "SUPER + V",
        pillPower:    "CTRL + ALT + delete",
        pillNotif:    "SUPER + SHIFT + N",
        pillRecord:   "SUPER + P",
        terminal:       "SUPER + T",
        terminalAlt:    "SUPER + Return",
        closeWindow:    "SUPER + Q",
        browser:        "SUPER + F",
        fullscreen:     "SUPER + SHIFT + F",
        exitHypr:       "SUPER + SHIFT + M",
        floatToggle:    "SUPER + W",
        pillVault:      "SUPER + SHIFT + P",
        voxDictate:     "Alt_R",
        floatCenter:    "SUPER + SHIFT + Space",
        fileManager:    "SUPER + E",
        fileManagerTui: "SUPER + SHIFT + E",
        toggleSplit:    "SUPER + J",
        notes:          "SUPER + O",
        screenshot:     "SUPER + SHIFT + S",
        screenOff:      "SUPER + SHIFT + F12",
        packWorkspaces: "SUPER + SHIFT + A",
        emptyWorkspace: "SUPER + Space",
        specialWorkspace: "SUPER + S",
        lockScreen:     "SUPER + L",
        workspace1: "SUPER + 1",
        workspace2: "SUPER + 2",
        workspace3: "SUPER + 3",
        workspace4: "SUPER + 4",
        workspace5: "SUPER + 5",
        workspace6: "SUPER + 6",
        workspace7: "SUPER + 7",
        workspace8: "SUPER + 8",
        workspace9: "SUPER + 9",
        workspace10: "SUPER + 0",
        moveWorkspace1: "SUPER + SHIFT + 1",
        moveWorkspace2: "SUPER + SHIFT + 2",
        moveWorkspace3: "SUPER + SHIFT + 3",
        moveWorkspace4: "SUPER + SHIFT + 4",
        moveWorkspace5: "SUPER + SHIFT + 5",
        moveWorkspace6: "SUPER + SHIFT + 6",
        moveWorkspace7: "SUPER + SHIFT + 7",
        moveWorkspace8: "SUPER + SHIFT + 8",
        moveWorkspace9: "SUPER + SHIFT + 9",
        moveWorkspace10: "SUPER + SHIFT + 0",
        themeSwitch: "SUPER + SHIFT + T",
        closeMouse: "mouse:277",
        focusLeft: "SUPER + left",
        focusRight: "SUPER + right",
        focusUp: "SUPER + up",
        focusDown: "SUPER + down",
        moveLeft: "SUPER + SHIFT + left",
        moveRight: "SUPER + SHIFT + right",
        moveUp: "SUPER + SHIFT + up",
        moveDown: "SUPER + SHIFT + down",
        resizeRight: "ALT + right",
        resizeLeft: "ALT + left",
        resizeUp: "ALT + up",
        resizeDown: "ALT + down",
        workspaceNext: "SUPER + mouse_down",
        workspacePrevious: "SUPER + mouse_up",
        dragWindow: "SUPER + mouse:272",
        resizeWindowMouse: "SUPER + mouse:273",
        micMute: "XF86AudioMicMute",
        volumeUp: "XF86AudioRaiseVolume",
        volumeDown: "XF86AudioLowerVolume",
        volumeMute: "XF86AudioMute",
        brightnessUp: "XF86MonBrightnessUp",
        brightnessDown: "XF86MonBrightnessDown",
        mediaNextAlt: "SUPER + XF86AudioRaiseVolume",
        mediaPreviousAlt: "SUPER + XF86AudioLowerVolume",
        mediaNext: "XF86AudioNext",
        mediaPause: "XF86AudioPause",
        mediaPlay: "XF86AudioPlay",
        mediaPrevious: "XF86AudioPrev",
        lidOn: "switch:on:Lid Switch",
        lidOff: "switch:off:Lid Switch"
    })

    readonly property var cfg: cfgFile.adapter
    Binding { target: Compositor; property: "keyboardLayoutMap"; value: root.cfg.keyboardLayoutMap }
    function saveCfgNow() { cfgFile.writeAdapter(); }

    readonly property var defaultCfg: ({
        fontFam: "JetBrainsMono Nerd Font", fontBody: "JetBrainsMono Nerd Font",
        fontDisplay: "JetBrainsMono Nerd Font", fontSize: 15, iconSize: 17,
        colFg: "#ffffff", colOn: "#ffffff", mutedAlpha: 0.45, themeId: "nothing",
        spacingUnit: 8, smallRadius: 10,
        pillH: 38, pillPos: "top", pillScreen: "auto", pillAutoHide: false, pillOverlay: true,
        pillKeepVisible: false, closePanaceaFirst: true,
        pillDrag: false, panelW: 540,
        monOverrides: "",
        notchMode: true, notchFlare: 12, collapsedW: 260, expandedH: 620,
        islandGap: 12, islandRadius: 0,
        reduceMotion: false, animMove: 230, animFade: 200, animHover: 150, animBounce: 0,
        clock12: false, clockSeconds: false, clockWeekday: true,
        clockTz: "auto", clockDateFmt: "d MMMM",
        notifDnd: false, notifTimeout: 5000, notifCritTimeout: 0, notifPreview: true,
        lockBlur: 32, lockHint: "",
        ccLayout: "", filesWindow: false, filesHidden: true, filesMode: "list",
        vaultCapture: false,
        vibrance: 50, mouseSens: 0, mouseRaw: false,
        keyboardLayouts: "us", keyboardVariants: "", keyboardOptions: "",
        recFps: 60, recDir: "~/Videos", recSysAudio: false, recMic: false, recMicDevice: "",
        weatherKey: "", weatherCity: "", weatherUnits: "metric",
        weatherOnIsland: false, systemLoadOnIsland: false, keyboardLayoutMap: "", featWidgets: false,
        widgetClockMode: "analog", widgetRightMode: "weather", widgetProgressMode: "day",
        widgetMusic: true,
        widgetScratchpad: true,
        termAlpha: 0.90,
        uiSounds: true
    })

    Process { id: pSound }
    function playSound(name) {
        if (root.cfg.uiSounds === false) return;
        var p = Quickshell.env("HOME") + "/.config/panacea/sounds/" + name + ".wav";
        pSound.command = ["sh", "-c", "command -v pw-play >/dev/null 2>&1 && pw-play \"$1\" >/dev/null 2>&1 || (command -v paplay >/dev/null 2>&1 && paplay \"$1\" >/dev/null 2>&1)", "_", p];
        pSound.running = false;
        pSound.running = true;
    }

    function resetCfg() {
        for (var k in root.defaultCfg) cfg[k] = root.defaultCfg[k];
        root.saveCfg();
    }

    Process { id: pMon; property string args: ""; command: ["sh", "-c", pMon.args] }

    function monCmd(n, o) {
        var mode = o.w + "x" + o.h + "@" + Number(o.rr).toFixed(2);
        var lua = "hl.monitor({ output=\"" + n + "\", mode=\"" + mode
                + "\", position=\"" + o.pos + "\", scale=" + Number(o.scale).toFixed(6)
                + ", transform=" + o.transform + ", vrr=" + (o.vrr ? 1 : 0) + " })";
        var legacy = n + "," + mode + "," + o.pos + "," + Number(o.scale).toFixed(6)
                   + ",transform," + o.transform + ",vrr," + (o.vrr ? 1 : 0);
        return "out=$(hyprctl eval '" + lua + "' 2>&1); case \"$out\" in ok*) ;; *) "
             + "hyprctl keyword monitor '" + legacy + "' ;; esac";
    }

    function monMap() {
        try { return JSON.parse(root.cfg.monOverrides || "{}") || ({}); }
        catch (e) { return ({}); }
    }

    function monApply(n, o) {
        pMon.args = root.monCmd(n, o);
        pMon.running = false;
        pMon.running = true;
        var all = root.monMap();
        all[n] = o;
        root.cfg.monOverrides = JSON.stringify(all);
        root.saveCfg();
        genMonTimer.restart();
    }

    Process { id: pGenMon }
    Timer {
        id: genMonTimer
        interval: 400
        onTriggered: {
            pGenMon.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/genmonitors.sh"];
            pGenMon.running = false;
            pGenMon.running = true;
        }
    }

    function monReplay() {
        var all = root.monMap(), parts = [];
        for (var n in all) parts.push(root.monCmd(n, all[n]));
        if (!parts.length) return;
        pMon.args = parts.join("; ");
        pMon.running = false;
        pMon.running = true;
    }

    Process { id: pVibrance }

    Timer {
        id: vibranceFlush
        interval: 160
        onTriggered: {
            pVibrance.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/vibrance.sh set "
                + root.cfg.vibrance];
            pVibrance.running = false;
            pVibrance.running = true;
            root.saveCfg();
        }
    }

    function applyVibrance(pct) {
        root.cfg.vibrance = Math.max(0, Math.min(100, Math.round(pct)));
        vibranceFlush.restart();
    }

    Process { id: pInput; property string args: ""; command: ["sh", "-c", pInput.args] }
    Process {
        id: pGenInput
        command: ["bash", root.scriptDir + "/geninput.sh"]
        stderr: StdioCollector {
            onStreamFinished: {
                var message = String(text).trim();
                if (message.length) root.keyboardInputError = message;
            }
        }
    }
    property bool keyboardInputPending: false
    property string keyboardInputError: ""
    function applyKeyboardLayouts(layouts, variants, options) {
        var l = String(layouts).replace(/\s+/g, "");
        var v = String(variants).replace(/\s+/g, "");
        var o = String(options).replace(/\s+/g, "");
        if (!/^[A-Za-z0-9_,+-]+$/.test(l) || l[0] === "," || l[l.length - 1] === "," || l.indexOf(",,") >= 0
                || !/^[A-Za-z0-9_,+-]*$/.test(v) || !/^[A-Za-z0-9_,:+-]*$/.test(o)) {
            root.keyboardInputError = root.tr("Invalid layout codes or switching options");
            return false;
        }
        var count = l.split(",").length;
        if (/^,*$/.test(v)) v = Array(count).join(",");
        if (v.split(",").length !== count) {
            root.keyboardInputError = root.tr("The number of variants must match the number of layouts");
            return false;
        }
        root.keyboardInputError = "";
        root.cfg.keyboardLayouts = l;
        root.cfg.keyboardVariants = v;
        root.cfg.keyboardOptions = o;
        root.keyboardInputPending = true;
        root.saveCfg();
        return true;
    }
    function applyInput() {
        var lua = "hl.config({ input = { sensitivity = "
                + Number(root.cfg.mouseSens).toFixed(3)
                + ", accel_profile = \"" + (root.cfg.mouseRaw ? "flat" : "adaptive") + "\""
                + " } })";
        var legacy = "hyprctl keyword input:sensitivity "
                   + Number(root.cfg.mouseSens).toFixed(3)
                   + "; hyprctl keyword input:accel_profile "
                   + (root.cfg.mouseRaw ? "flat" : "adaptive");
        pInput.args = "out=$(hyprctl eval '" + lua + "' 2>&1); "
                    + "case \"$out\" in ok*) ;; *) " + legacy + " ;; esac";
        pInput.running = false;
        pInput.running = true;
        root.saveCfg();
    }

    property string wiredName: ""
    readonly property bool wiredOn: root.wiredName.length > 0

    Process {
        id: pWired
        command: ["sh", "-c",
            "for d in /sys/class/net/*; do " +
            "n=${d##*/}; " +
            "[ -d \"$d/wireless\" ] && continue; " +
            "case $n in lo|docker*|veth*|br-*|virbr*|tun*|tap*|wg*|zt*|tailscale*) continue ;; esac; " +
            "[ \"$(cat $d/type 2>/dev/null)\" = 1 ] || continue; " +
            "[ \"$(cat $d/carrier 2>/dev/null)\" = 1 ] && { echo $n; exit 0; }; " +
            "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                root.wiredName = lines.length ? lines[lines.length - 1].trim() : "";
            }
        }
    }

    Timer {
        interval: root.expanded ? 3000 : 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { pWired.running = false; pWired.running = true; }
    }

    property var fontList: ["JetBrainsMono Nerd Font"]
    Process {
        id: pFonts
        command: ["sh", "-c",
            "fc-list :spacing=100 family | tr ',' '\\n' | sed 's/^ *//' | sort -u | grep -v '^$'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.trim().split("\n").filter(x => x.length);
                if (a.length) root.fontList = a;
            }
        }
    }

    function saveCfg() { cfgFile.writeAdapter(); }

    readonly property string localeId: String(cfg.lang || "en")
    readonly property string languageCode: "en"
    readonly property bool isEn: true
    function tr(k) { return k; }

    Process {
        id: pGreeterLocale
        command: ["sh", "-c",
            "d=/var/lib/panacea; [ -w \"$d\" ] || exit 0; " +
            "printf 'import QtQuick 2.15\\nQtObject { property string lang: \"%s\" }\\n' " +
            "\"$1\" > \"$d/locale.qml\" && chmod 644 \"$d/locale.qml\"",
            "_", root.cfg.lang]
    }
    Process {
        id: pGreeterTheme
        command: ["sh", "-c",
            "d=/var/lib/panacea; [ -w \"$d\" ] || exit 0; " +
            "printf 'import QtQuick 2.15\\nQtObject {\\n" +
            "  property color value: \"%s\"\\n" +
            "  property color fg: \"%s\"\\n" +
            "  property color muted: \"%s\"\\n" +
            "  property color bg: \"%s\"\\n}\\n' " +
            "\"$1\" \"$2\" \"$3\" \"$4\" > \"$d/accent.qml\" " +
            "&& chmod 644 \"$d/accent.qml\"",
            "_",
            String(root.colOn), String(root.colFg),
            String(root.colMuted), String(root.colBg)]
    }
    Process {
        id: pTermAlpha
        command: ["sh", "-c",
            "d=\"$HOME/.config/ghostty\"; mkdir -p \"$d\" || exit 0; " +
            "printf 'background-opacity = %s\\n' \"$1\" > \"$d/opacity\"; " +
            "pgrep -x ghostty | xargs -r kill -USR2",
            "_", root.cfg.termAlpha.toFixed(2)]
    }
    Timer {
        id: termAlphaFlush
        interval: 180
        onTriggered: {
            pTermAlpha.running = false;
            pTermAlpha.running = true;
        }
    }
    function applyTermAlpha() { termAlphaFlush.restart(); }

    Process {
        id: pTermRestart
        command: ["sh", "-c",
            "pkill -x foot >/dev/null 2>&1; sleep 0.4; " +
            "setsid -f foot --server >/dev/null 2>&1"]
    }
    Process { id: pDetached }
    function runDetached(cmd) {
        Compositor.exec(cmd);
    }

    function restartTerminalServer() {
        pTermRestart.running = false;
        pTermRestart.running = true;
    }

    readonly property string termBg: "171717"
    Process {
        id: pTermTheme
        command: ["sh", "-c",
            "f=\"$HOME/.config/foot/panacea-theme\"; mkdir -p \"$(dirname \"$f\")\" || exit 0; " +
            "if [ -n \"$1\" ]; then " +
            "printf '[colors-dark]\\nbackground=%s\\n' \"$1\" > \"$f\"; " +
            "else : > \"$f\"; fi",
            "_", root.termBg]
    }
    function syncTermTheme() {
        pTermTheme.running = false;
        pTermTheme.running = true;
    }

    function syncGreeterTheme() {
        pGreeterTheme.running = false;
        pGreeterTheme.running = true;
    }
    onThemeChanged: {
        root.syncGreeterTheme();
        root.syncTermTheme();
    }

    property string sysLang: "en"
    property bool   sysLangPending: false
    function canonicalLocale(value) {
        if (value === "en") return "en_US";
        return String(value || "");
    }
    readonly property bool systemLocaleMatches: canonicalLocale(root.sysLang) === canonicalLocale(root.cfg.lang)

    Process {
        id: pLocaleGet
        running: true
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/locale.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim().split("\n").pop().trim();
                if (s.length) root.sysLang = s;
            }
        }
    }

    Process {
        id: pLocaleSet
        onExited: {
            root.sysLangPending = false;
            pLocaleGet.running = false;
            pLocaleGet.running = true;
        }
    }

    function setLang(code) {
        if (root.cfg.lang === code) return;
        root.cfg.lang = code;
        root.saveCfg();

        root.sysLangPending = true;
        pLocaleSet.command = root.rootCmd(["locale", code],
            ["pkexec", Quickshell.env("HOME") + "/.config/panacea/scripts/locale.sh", "set", code]);
        pLocaleSet.running = false;
        pLocaleSet.running = true;
    }

    function syncGreeterLocale() {
        pGreeterLocale.running = false;
        pGreeterLocale.running = true;
    }
    onLocaleIdChanged: {
        root.syncGreeterLocale();
        if (root.cfg.featWidgets || root.cfg.weatherOnIsland) root.refreshWeather();
    }

    readonly property bool cornersWanted:
        !(root.settingsMode || root.wallsOpen || root.pillHidden)
    property bool cornersOn: false
    Timer {
        id: cornerReveal
        interval: root.animMs + 40
        onTriggered: root.cornersOn = true
    }
    onCornersWantedChanged: {
        if (root.cornersWanted) {
            cornerReveal.restart();
        } else {
            cornerReveal.stop();
            root.cornersOn = false;
        }
    }

    Process {
        id: pBootOs
        stderr: StdioCollector {
            onStreamFinished: {
                var t = String(text).trim();
                if (t.length === 0) return;
                console.warn("bootos:", t);
                pBootOsSay.command = ["notify-send", "-u", "critical",
                                      root.tr("Could not restart"), t];
                pBootOsSay.running = false;
                pBootOsSay.running = true;
            }
        }
    }
    Process { id: pBootOsSay }

    Process { id: pOpenWith }
    function openFileWith(path, desktopFile) {
        if (!path) return;
        var s = root.scriptDir + "/files.sh";
        pOpenWith.command = desktopFile && desktopFile.length
            ? ["sh", "-c", s + ' open "$1" "$2"', "_", String(path), String(desktopFile)]
            : ["sh", "-c", s + ' open "$1"', "_", String(path)];
        pOpenWith.running = false;
        pOpenWith.running = true;
    }

    readonly property string rootHelper: "/usr/local/lib/panacea/panacea-root"
    property bool rootHelperOk: false
    Process {
        running: true
        command: ["test", "-x", root.rootHelper]
        onExited: code => root.rootHelperOk = (code === 0)
    }
    function rootCmd(args, legacy) {
        return root.rootHelperOk ? ["pkexec", root.rootHelper].concat(args) : legacy;
    }

    function bootIntoSystem(id) {
        if (!id) return;
        pBootOs.command = root.rootCmd(["boot", String(id)],
            ["pkexec", root.scriptDir + "/bootos.sh", "boot", String(id)]);
        pBootOs.running = false;
        pBootOs.running = true;
    }

    readonly property string version: "1.0.24"

    property string updStatus: ""
    property string updSubject: ""
    property string updLatest: ""
    property string updCurrent: ""
    property bool   updBusy: false
    property string updStep: ""
    property string updError: ""
    property string updNotified: ""

    readonly property bool updateAvailable: updStatus === "behind"

    readonly property string updErrorText: {
        switch (root.updError) {
        case "":         return "";
        case "nogit":    return root.tr("git is not installed");
        case "offline":  return root.tr("Cannot reach GitHub");
        case "download": return root.tr("Could not download the update");
        case "install":  return root.tr("The installer failed");
        default:         return root.tr("The update failed");
        }
    }

    property bool updChecking: false

    function checkUpdate() {}

    function applyUpdate() {}

    readonly property var updSteps: [
        { id: "download",      w: 45 },
        { id: "selfupdate",    w: 2  },
        { id: "backup",        w: 4  },
        { id: "install",       w: 16 },
        { id: "greeter",       w: 2  },
        { id: "restore",       w: 4  },
        { id: "restart",       w: 4  },
        { id: "done",          w: 0  }
    ]
    function updDownload(pct) {
        if (!root.updBusy || root.updStep !== "download") return;
        var v = root.updStepPercent + (root.updStepCeil - root.updStepPercent) * pct / 100;
        if (v > root.updCreepAt) {
            root.updCreepAt = v;
            root.busyProgress = Math.round(v);
        }
    }
    readonly property real updWeightTotal: {
        var t = 0;
        for (var i = 0; i < root.updSteps.length; i++) t += root.updSteps[i].w;
        return t > 0 ? t : 1;
    }
    function updStepIndex(id) {
        for (var i = 0; i < root.updSteps.length; i++)
            if (root.updSteps[i].id === id) return i;
        return -1;
    }
    readonly property int updStepPercent: {
        var i = root.updStepIndex(root.updStep);
        if (i < 0) return 0;
        var acc = 0;
        for (var k = 0; k < i; k++) acc += root.updSteps[k].w;
        return Math.round(acc * 100 / root.updWeightTotal);
    }
    readonly property int updStepCeil: {
        var i = root.updStepIndex(root.updStep);
        if (i < 0) return 0;
        var acc = 0;
        for (var k = 0; k <= i; k++) acc += root.updSteps[k].w;
        return Math.round(acc * 100 / root.updWeightTotal);
    }

    property real updCreepAt: 0
    readonly property int updProgress: Math.max(0, Math.min(100, Math.round(root.updCreepAt)))

    Timer {
        id: updCreep
        interval: 180
        repeat: true
        running: root.updBusy && root.updStep !== "done"
        onTriggered: {
            var to = Math.max(root.updStepCeil, root.updStepPercent + 5);
            if (root.updCreepAt >= to) return;
            var left = to - root.updCreepAt;
            root.updCreepAt = Math.min(to, root.updCreepAt + Math.max(0.3, left * 0.05));
            root.busyProgress = Math.round(root.updCreepAt);
        }
    }
    onUpdStepChanged: {
        if (!root.updBusy) return;
        if (root.updStepPercent > root.updCreepAt)
            root.updCreepAt = root.updStepPercent;
        if (root.updStep === "done") root.updCreepAt = 100;
        root.busyProgress = Math.round(root.updCreepAt);
    }

    function updParse(text, done) {
        var lines = String(text).trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
            var kv = lines[i].split("=");
            if (kv.length < 2) continue;
            var k = kv[0].trim(), v = lines[i].slice(kv[0].length + 1).trim();
            if (k === "status")       root.updStatus = v;
            else if (k === "subject") root.updSubject = v;
            else if (k === "latest")  root.updLatest = v;
            else if (k === "current") root.updCurrent = v;
            else if (k === "step")    root.updStep = v;
            else if (k === "error")   root.updError = v;
            else if (k === "dl")      root.updDownload(parseInt(v, 10) || 0);
            else if (k === "missing")  root.missingDeps = v;
            else if (k === "obsolete") root.obsoleteDeps = v;
            else if (k === "version") root.updCurrent = v;
        }
        if (!done) return;
        if (root.updStatus === "behind" && root.updLatest.length
                && root.updLatest !== root.cfg.updNotifiedVer) {
            root.updNotified = root.updLatest;
            root.cfg.updNotifiedVer = root.updLatest;
            root.saveCfg();
            pUpdNotify.running = true;
        }
    }

    property int updNotifId: -1
    Process {
        id: pUpdNotify
        command: ["notify-send", "-p", "-a", "Panacea", "-i",
                  Quickshell.env("HOME") + "/.config/panacea/assets/logo-128.png",
                  root.tr("A Panacea update is available"), root.updSubject]
        stdout: StdioCollector {
            onStreamFinished: root.updNotifId = parseInt(String(text).trim()) || -1
        }
    }

    property var whatsNew: []
    readonly property bool whatsNewOpen: whatsNew.length > 0

    FileView {
        id: whatsNewFile
        path: Quickshell.env("HOME") + "/.config/panacea/.whatsnew"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var t = String(whatsNewFile.text()).trim();
            root.whatsNew = t.length ? t.split("\n").filter(x => x.trim().length) : [];
        }
        onLoadFailed: root.whatsNew = []
    }

    Timer {
        interval: 3000
        running: root.whatsNew.length === 0
        repeat: true
        triggeredOnStart: true
        property int tries: 0
        onTriggered: {
            whatsNewFile.reload();
            if (++tries > 10) running = false;
        }
    }

    property string missingDeps: ""

    Process { id: pCopyText }
    function copyText(t) {
        pCopyText.running = false;
        pCopyText.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", String(t)];
        pCopyText.running = true;
    }

    FileView {
        id: missingDepsFile
        path: Quickshell.env("HOME") + "/.config/panacea/.missingdeps"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.missingDeps = String(missingDepsFile.text()).trim()
        onLoadFailed: root.missingDeps = ""
    }

    property string obsoleteDeps: ""
    FileView {
        id: obsoleteDepsFile
        path: Quickshell.env("HOME") + "/.config/panacea/.obsoletedeps"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.obsoleteDeps = String(obsoleteDepsFile.text()).trim()
        onLoadFailed: root.obsoleteDeps = ""
    }

    property string keptEdits: ""
    FileView {
        id: keptEditsFile
        path: Quickshell.env("HOME") + "/.config/panacea/.keptedits"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.keptEdits = String(keptEditsFile.text()).trim().split("\n")
                      .map(function (l) { return l.replace(/^kept /, ""); }).join("\n")
        onLoadFailed: root.keptEdits = ""
    }

    function dismissWhatsNew() {
        root.whatsNew = [];
        root.keptEdits = "";
        root.missingDeps = "";
        root.obsoleteDeps = "";
        pWhatsNewClear.running = true;
    }
    Process {
        id: pWhatsNewClear
        command: ["sh", "-c",
                  "rm -f \"$1/.whatsnew\" \"$1/.missingdeps\" \"$1/.obsoletedeps\" \"$1/.keptedits\"", "_",
                  Quickshell.env("HOME") + "/.config/panacea"]
    }

    readonly property string scriptDir:
        Quickshell.env("HOME") + "/.config/panacea/scripts"

    signal cancelCaptureRequested()

    property int settingsTab: 0
    property string settingsSection: ""
    function openSettingsAt(sectionId) {
        root.settingsSection = sectionId;
        if (root.page !== "settings" || !root.expanded) root.togglePage("settings");
    }

    Process { id: pGenBinds }
    property bool bindsPending: false
    function applyBinds() {
        root.bindsPending = true;
        saveCfg();
        bindsFallback.restart();
    }
    function runGenBinds() {
        if (!root.bindsPending) return;
        root.bindsPending = false;
        bindsFallback.stop();
        pGenBinds.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/genbinds.sh"];
        pGenBinds.running = true;
    }
    Timer { id: bindsFallback; interval: 700; onTriggered: root.runGenBinds() }

    Process {
        id: pBindsHeal
        running: false
        command: ["sh", "-c",
            "[ -f \"$HOME/.config/hypr/lua/binds_data.lua\" ] "
            + "|| \"$HOME/.config/panacea/scripts/genbinds.sh\""]
    }
    Connections {
        target: cfgFile
        function onSaved() {
            root.runGenBinds();
            if (root.keyboardInputPending) {
                root.keyboardInputPending = false;
                pGenInput.running = false;
                pGenInput.running = true;
            }
        }
    }

    readonly property var themes: Themes.list
    function themeOf(id) { return Themes.of(id); }
    property var ricePal: null
    FileView {
        id: ricePalFile
        path: Quickshell.env("PANACEA_PALETTE") || (Quickshell.env("HOME") + "/.cache/theme/palette.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.ricePal = JSON.parse(ricePalFile.text()); } catch (e) { root.ricePal = null; }
        }
    }
    readonly property var theme: {
        var t = themeOf(cfg.themeId);
        var p = root.ricePal;
        if (!p || !p.accent) return t;
        if (p.mode === "paper")
            return { id: t.id, name: t.name, world: true, line: t.line, fonts: t.fonts,
                     bg: p.bg, fg: p.fg, on: p.fg, ok: p.accent, crit: p.red };
        if (cfg.themeId !== "sakuga" || p.world !== "sakuga") return t;
        return { id: t.id, name: t.name, world: true, line: t.line, fonts: t.fonts,
                 bg: p.crust, fg: p.fg, on: p.accent, ok: p.accent2, crit: p.red };
    }
    readonly property bool themeNothing: true

    readonly property real dotHBig:   root.fontSize + 10
    readonly property real dotHClock: root.fontSize - 1
    readonly property real dotHSmall: root.fontSize - 3
    readonly property real dotHTiny:  root.fontSize - 5

    function fgOn(c) {
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.6
               ? root.colBg : "#ffffff";
    }

    readonly property color colBg:     theme.bg
    readonly property color colFg:     theme.fg
    Binding { target: World; property: "id"; value: root.cfg.themeId }
    onColFgChanged: Pal.fg = colFg
    onColBgChanged: Pal.bg = colBg
    readonly property color colMuted:  Qt.rgba(colFg.r, colFg.g, colFg.b, cfg.mutedAlpha)
    readonly property color colLine:   Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10)
    readonly property color colHover:  Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10)
    readonly property color colOn:     theme.on
    readonly property color colOk:     theme.ok
    readonly property color colCrit:   theme.crit

    function tint(c) { return root.colFg; }
    readonly property color colWarn: root.tint("#fbbf24")
    readonly property string fontFam:  cfg.fontFam
    readonly property string fontBody:    cfg.fontBody || cfg.fontFam
    readonly property string fontDisplay: cfg.fontDisplay || cfg.fontFam
    readonly property int fontSize:    cfg.fontSize
    readonly property int iconSize:    cfg.iconSize
    readonly property int unit:        cfg.spacingUnit
    readonly property int radiusS:     cfg.smallRadius

    readonly property int pillH: cfg.pillH

    readonly property string pillPos: {
        var p = String(cfg.pillPos || "top");
        return (p === "bottom" || p === "left" || p === "right") ? p : "top";
    }
    readonly property bool pillAtTop:    pillPos === "top"
    readonly property bool pillAtBottom: pillPos === "bottom"
    readonly property bool pillAtLeft:   pillPos === "left"
    readonly property bool pillAtRight:  pillPos === "right"
    readonly property bool pillSide: pillAtLeft || pillAtRight

    property bool  pillDragging: false
    property real  dragDX: 0
    property real  dragDY: 0
    property string dragEdge: ""

    function edgeAt(cx, cy) {
        var w = root.width, h = root.height;
        var dTop = cy, dBottom = h - cy, dLeft = cx, dRight = w - cx;
        var m = Math.min(dTop, dBottom, dLeft, dRight);
        if (m > Math.min(w, h) * 0.25) return "";
        if (m === dTop)    return "top";
        if (m === dBottom) return "bottom";
        if (m === dLeft)   return "left";
        return "right";
    }

    function dropPill() {
        var edge = root.dragEdge;
        root.pillDragging = false;
        root.dragEdge = "";
        root.dragDX = 0;
        root.dragDY = 0;
        if (edge.length && edge !== root.pillPos) {
            cfg.pillPos = edge;
            root.saveCfg();
        }
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
        root.collapse();
    }

    property real pillRectX: 0
    property real pillRectY: 0
    property real pillRectW: 0
    property real pillRectH: 0
    readonly property int panelW: cfg.panelW
    readonly property int gap: 5
    readonly property int cornerR: cfg.notchMode ? cfg.notchFlare : 0

    readonly property bool noMotion: cfg.reduceMotion
    readonly property int animMs:   noMotion ? 0 : cfg.animMove
    readonly property int animFade: noMotion ? 0 : cfg.animFade
    readonly property int animHover: noMotion ? 0 : cfg.animHover
    readonly property real animBounce: noMotion ? 0 : cfg.animBounce / 100
    readonly property real easeOvershoot: animBounce * 1.7
    readonly property int animFast: Math.round(animMs * 0.52)
    readonly property int animQuick: Math.round(animMs * 0.48)

    property bool morphing: false
    onExpandedChanged: {
        clockTick.restart();
        morphing = true;
        morphTimer.restart();
        if (!expanded) toastPump.restart();
    }
    onPageChanged:     { morphing = true; morphTimer.restart() }
    Timer { id: morphTimer; interval: root.animMs + 140; onTriggered: root.morphing = false }

    property bool expanded: false
    property string vpnCountry: "--"
    property string vpnCountryName: ""
    property bool vpnConnected: false
    property var vpnActiveIds: []
    readonly property bool vpnBusy: vpnQuick.running || vpnClientState === "busy"
    property string vpnClientState: "unknown"
    property string vpnQuickAction: ""
    property string vpnAnnouncement: ""
    function announceVpnChange(action) { vpnAnnouncement = action; refreshVpnGeo(); }
    function refreshVpnGeo() { if (!vpnGeo.running) vpnGeo.running = true; }
    function refreshVpnStatus() { if (!vpnStatus.running) vpnStatus.running = true; }
    function togglePreferredVpn() {
        if (vpnBusy) return;
        if (cfg.vpnPreferredClient) {
            vpnQuick.command = ["python3", root.scriptDir + "/vpn.py", "client-toggle", cfg.vpnPreferredClient];
        } else if (cfg.vpnPreferred) {
            vpnQuickAction = vpnActiveIds.indexOf(cfg.vpnPreferred) >= 0 ? "down" : "up";
            vpnQuick.command = ["python3", root.scriptDir + "/vpn.py", vpnQuickAction, cfg.vpnPreferred];
        } else { return; }
        vpnQuick.running = true;
    }
    Process {
        id: vpnStatus
        command: root.cfg.vpnPreferredClient ? ["python3", root.scriptDir + "/vpn.py", "client-status", root.cfg.vpnPreferredClient] : ["python3", root.scriptDir + "/vpn.py", "list"]
        stdout: StdioCollector { onStreamFinished: { try {
            var d = JSON.parse(text);
            if (vpnQuick.running) return;
            if (d.clientState) { root.vpnClientState = d.clientState; root.vpnConnected = d.clientState === "connected"; }
            else if (!root.cfg.vpnPreferredClient) { root.vpnActiveIds = (d.profiles || []).filter(p => p.active).map(p => p.id); root.vpnConnected = root.vpnActiveIds.length > 0 || !!d.tunnelActive; }
        } catch(e) {} } }
    }
    Process {
        id: vpnGeo
        command: ["python3", root.scriptDir + "/vpn.py", "geo"]
        stdout: StdioCollector { onStreamFinished: {
            var d = {}; try { d = JSON.parse(text); } catch(e) {}
            if (d.country) { root.vpnCountry = d.country; root.vpnCountryName = d.name || ""; }
            if (root.vpnAnnouncement) {
                var title = root.vpnAnnouncement === "up" ? root.tr("VPN connected") : root.tr("VPN disconnected");
                vpnNotify.command = ["notify-send", "--app-name", "Panacea VPN", title,
                    d.country ? (String(d.name || d.country) + " · " + d.country) : root.tr("Region unavailable")];
                vpnNotify.running = true; root.vpnAnnouncement = "";
            }
        } }
    }
    Process {
        id: vpnQuick
        stdout: StdioCollector { onStreamFinished: { try {
            var d = JSON.parse(text);
            if (d.ok) {
                if (d.clientState) { root.vpnClientState = d.clientState; root.vpnConnected = d.clientState === "connected"; }
                else { root.vpnActiveIds = (d.profiles || []).filter(p => p.active).map(p => p.id); root.vpnConnected = root.vpnActiveIds.length > 0 || !!d.tunnelActive; }
                root.announceVpnChange(d.action || root.vpnQuickAction);
            }
            else { vpnNotify.command = ["notify-send", "--app-name", "Panacea VPN", root.tr("VPN error"), String(d.error || "")]; vpnNotify.running = true; }
        } catch(e) {} } }
    }
    Process { id: vpnNotify }
    Process { id: vpnClient }
    Timer { id: vpnGeoDelay; interval: 3000; onTriggered: root.refreshVpnGeo() }
    Timer { interval: 15000; running: false; repeat: true; onTriggered: root.refreshVpnStatus() }
    Timer { interval: 180000; running: false; repeat: true; triggeredOnStart: true; onTriggered: root.refreshVpnGeo() }
    property bool chatFilePickerOpen: false
    signal chatFilesPicked(var paths)
    property string islandChatService: "chat"
    property bool minimalPill: true
    property bool peekOpen: false
    property bool clockFlying: false
    property var ccClockItem: null
    property var peekClockItem: null
    property var islandChatMessages: []
    property var islandAgentEvents: []
    property string page: "main"
    property string quickFilePath: ""
    property var quickFilePaths: []
    property bool fileOverIsland: false
    property real fileAbsorb: 0
    SequentialAnimation {
        id: fileAbsorbAnimation
        NumberAnimation { target: root; property: "fileAbsorb"; to: 1; duration: root.noMotion ? 0 : 130; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "fileAbsorb"; to: 0; duration: root.noMotion ? 0 : 260; easing.type: Easing.OutBack }
    }
    Timer {
        id: quickFileOpenTimer
        interval: root.noMotion ? 1 : 170
        onTriggered: {}
    }
    function openDroppedFile(urls) {
        if (!urls || !urls.length) return;
        var paths = [];
        for (var i = 0; i < urls.length; i++) {
            var url = String(urls[i]);
            if (url.indexOf("file:///") !== 0) { sayToast(tr("Files"), tr("Only local files are supported")); return; }
            try { paths.push(decodeURIComponent(url.substring(7))); }
            catch (e) { sayToast(tr("Files"), tr("Cannot read the path")); return; }
        }
        quickFilePaths = paths; quickFilePath = paths[0];
        fileOverIsland = false;
        fileAbsorbAnimation.restart();
        quickFileOpenTimer.restart();
    }

    property string mediaPath: ""
    readonly property int mediaStageH: Math.round((screen ? screen.height : 1080) * 0.58)
    property bool mediaCrop: false
    function mediaCropToggle() { root.mediaCrop = !root.mediaCrop; }

    property bool   wallpaperPickMode: false
    property string wallpaperPick: ""
    function startWallpaperPick() {
        wallsOpen = false;
        wallpaperPickMode = true;
        togglePage("files");
    }
    function finishWallpaperPick(path) {
        wallpaperPickMode = false;
        collapse();
        wallpaperPick = path;
        openWalls();
    }
    function cancelWallpaperPick() { wallpaperPick = ""; }

    function openMedia(path) {
        return;
        root.mediaCrop = false;
        root.mediaPath = path;
        pageResetTimer.stop();
        root.page = "media";
        root.expanded = true;
        root.holdOpen = true;
    }

    property bool fullscreenActive: Compositor.isHyprland ? false : Compositor.isFullscreen

    Process {
        id: pFullscreen
        running: Compositor.isHyprland
        command: ["sh", "-c",
            "hyprctl activewindow -j 2>/dev/null | grep -o '\"fullscreen\": *[0-9]*' | grep -o '[0-9]*$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Compositor.isHyprland) root.fullscreenActive = parseInt(text.trim()) > 0;
            }
        }
    }
    Timer { id: fsProbe; interval: 120; onTriggered: if (Compositor.isHyprland) pFullscreen.running = true }
    Timer {
        interval: 5000; running: false; repeat: true; triggeredOnStart: true
        onTriggered: pFullscreen.running = true
    }

    Connections {
        target: Hyprland
        enabled: Compositor.isHyprland
        function onRawEvent(event) {
            var n = String(event.name);
            if (n === "fullscreen" || n === "activewindow" || n === "activewindowv2"
                || n === "closewindow" || n === "openwindow" || n === "workspace"
                || n === "focusedmon")
                fsProbe.restart();
            if (n === "configreloaded") monReplayTimer.restart();
        }
    }
    Timer {
        id: monReplayTimer
        interval: 400
        onTriggered: {
            root.monReplay();
            root.applyInput();
            pVibrance.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/vibrance.sh set "
                + root.cfg.vibrance];
            pVibrance.running = false;
            pVibrance.running = true;
        }
    }

    Component.onCompleted: {
        Pal.fg = root.colFg; Pal.bg = root.colBg;
        fsProbe.restart();
        syncGreeterLocale();
        monReplayTimer.restart();
        syncGreeterTheme();
        syncTermTheme();
        root.cornersOn = root.cornersWanted;
        root.wsList = root.wsRaw;
    }

    Item {
        id: fileDrag
        width: 1
        height: 1
        visible: false

        property string uri: ""

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": fileDrag.uri,
                          "text/plain": decodeURI(fileDrag.uri.replace(/file:\/\//g, "")) })
    }
    Timer {
        id: fileDragStart
        interval: 90
        onTriggered: fileDrag.Drag.active = true
    }

    property bool overviewOpen: false
    function openOverview() {
        if (!Compositor.isHyprland) {
            Compositor.refresh();
        } else {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
        root.overviewOpen = true;
    }
    function closeOverview() { root.overviewOpen = false; }

    function gotoWorkspace(id) {
        if (!Compositor.isHyprland) {
            Compositor.focusWorkspace(id);
        } else if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        } else {
            Hyprland.dispatch("workspace " + id);
        }
    }
    function toggleOverview() {
        if (root.overviewOpen) closeOverview(); else openOverview();
    }

    property bool launchpadOpen: false
    property bool launchpadWarm: false
    function openLaunchpad() {
        if (!cfg.featLaunchpad) return;
        if (root.expanded) root.collapse();
        if (root.overviewOpen) root.closeOverview();
        root.launchpadWarm = true;
        root.launchpadOpen = true;
    }
    function closeLaunchpad() { root.launchpadOpen = false; }
    Timer {
        interval: 4000
        running: root.cfg.featLaunchpad && !root.launchpadWarm
        onTriggered: root.launchpadWarm = true
    }
    function toggleLaunchpad() {
        if (root.launchpadOpen) closeLaunchpad(); else openLaunchpad();
    }

    property bool keysWindowOpen: false
    function toggleKeysWindow() { root.keysWindowOpen = !root.keysWindowOpen; }

    property bool wallsOpen: false
    function openWalls() {
        if (!cfg.featThemes) return;
        collapse();
        root.wallsOpen = true;
        root.refreshWalls();
    }
    function closeWalls() { root.wallsOpen = false; }

    property var wallList: []
    property bool wallListReady: false
    Process {
        id: pWallList
        command: ["sh", "-c", root.scriptDir + "/themes.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 5) continue;
                    rows.push({
                        wName:   p[0],
                        wThumb:  p[1],
                        wActive: p[2] === "yes",
                        wOwn:    p[3] === "yes",
                        wPath:   p[4]
                    });
                }
                root.wallList = rows;
                root.wallListReady = true;
            }
        }
    }
    readonly property string currentWallThumb: {
        for (var i = 0; i < wallList.length; i++) {
            if (wallList[i].wActive) return wallList[i].wThumb;
        }
        return "";
    }

    function refreshWalls() {
        pWallList.running = false;
        pWallList.running = true;
        root.refreshLiveWalls();
    }

    property var liveList: []
    property bool liveListReady: false
    property string liveDir: ""

    Process {
        id: pLiveDir
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "dir"]
        running: root.cfg.featThemes
        stdout: StdioCollector { onStreamFinished: root.liveDir = text.trim() }
    }
    Process {
        id: pLiveList
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 4) continue;
                    rows.push({
                        wName:   p[0],
                        wThumb:  p[1],
                        wActive: p[2] === "yes",
                        wOwn:    true,
                        wPath:   p[3]
                    });
                }
                root.liveList = rows;
                root.liveListReady = true;
            }
        }
    }
    function refreshLiveWalls() {
        pLiveList.running = false;
        pLiveList.running = true;
    }
    function openLiveFolder() {
        if (root.liveDir.length === 0) return;
        root.closeWalls();
        root.openFilesAt(root.liveDir);
    }
    Timer {
        interval: 4000
        running: root.cfg.featThemes
        onTriggered: root.refreshWalls()
    }
    function toggleWalls() {
        if (root.wallsOpen) closeWalls(); else openWalls();
    }

    readonly property var overviewToplevels: {
        var out = [];
        if (!root.overviewOpen) return out;
        if (!Compositor.isHyprland) return Compositor.toplevels;
        var all = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < all.length; i++) {
            var t = all[i];
            if (!t) continue;
            var o = t.lastIpcObject;
            if (!o || !o.at || !o.size) continue;
            if (o.hidden || o.workspace === undefined) continue;
            out.push({
                wayland: t.wayland,
                geo: {
                    x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1],
                    ws: o.workspace.id, cls: String(o.initialClass || o.class || "")
                }
            });
        }
        return out;
    }

    signal filesChanged()

    function startFileDrag(path, fromWindow) {
        var list = Array.isArray(path) ? path : [path];
        fileDrag.uri = list.map(function (p) { return "file://" + String(p).split("/").map(encodeURIComponent).join("/"); }).join("\r\n");
        if (fromWindow) { fileDrag.Drag.active = true; return; }
        root.collapse();
        fileDragStart.restart();
    }

    readonly property int filesListH: Math.round((screen ? screen.height : 1080) * 0.64)

    property string filesDir: Quickshell.env("HOME")
    property var trayMenuItem: null
    property bool holdOpen: false
    onHoldOpenChanged: if (holdOpen) refocusTimer.restart()
    Timer {
        id: refocusTimer
        interval: 60
        onTriggered: if (contentLoader.item) contentLoader.item.forceActiveFocus()
    }

    readonly property bool launcherOpen: expanded && page === "launcher"

    function collapse() {
        expanded = false;
        chatFilePickerOpen = false;
        holdOpen = false;
        weatherDetailsOpen = false;
        pageResetTimer.restart();
    }
    Timer {
        id: pageResetTimer
        interval: root.animMs + 40
        onTriggered: if (!root.expanded) { root.page = "main"; root.trayMenuItem = null; }
    }

    function pageEnabled(name) {
        if (["vpn", "chat", "launcher", "files", "media", "quickfile", "auth", "vault", "vaultsave", "agents"].indexOf(name) >= 0) return false;
        switch (name) {
            case "launcher":  return cfg.featLauncher;
            case "wifi":      return cfg.featWifi;
            case "bt":        return cfg.featBluetooth;
            case "clip":      return cfg.featClipboard;
            case "notif":     return cfg.featNotifications;
            case "cal":       return cfg.featCalendar;
            case "record":    return cfg.featRecord;
            case "files":     return cfg.featFiles;
            case "media":     return cfg.featMedia;
            case "vault":     return cfg.featVault;
            case "vaultsave": return cfg.featVault;
            case "audio":     return cfg.featAudio;
            case "power":     return cfg.featPowermenu;
            default:          return true;
        }
    }

    property int filesWindowSeq: 0
    ListModel { id: filesWindows }

    function openFilesWindow(startDir) {
        root.filesWindowSeq++;
        filesWindows.append({ wid: root.filesWindowSeq,
                              startDir: String(startDir || "") });
    }

    property string filesStartDir: ""
    function openFilesAt(path) {
        var p = String(path || "");
        if (p.length === 0) return;
        if (cfg.filesWindow) { root.openFilesWindow(p); return; }
        root.filesStartDir = p;
        if (root.page === "files" && root.expanded) root.collapse();
        root.togglePage("files");
    }
    function closeFilesWindow(wid) {
        for (var i = 0; i < filesWindows.count; i++) {
            if (filesWindows.get(i).wid !== wid) continue;
            filesWindows.remove(i);
            return;
        }
    }

    function openSub(name) {
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
    }

    function togglePage(name) {
        if (name === "worlds") {
            if (worldWallsLoader.item && worldWallsLoader.item.open) worldWallsLoader.item.hide();
            else openWorldWalls("");
            return;
        }
        if (!pageEnabled(name)) return;
        if (name === "files" && cfg.filesWindow) { openFilesWindow(); return; }
        if (expanded && page === name) { collapse(); return; }
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
        if (name === "wifi" && wifiOn) { refreshWifiList(); scanWifi(); }
        else if (name === "bt" && btOn) scanBt();
    }
    function openLauncher() {
        if (root.expanded) root.collapse();
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/rofi/scripts/launcher.sh", "apps"]);
    }
    function closeLauncher() { collapse(); }
    function toggleLauncher() {
        openLauncher();
    }

    property int agentsEpoch: 0
    function openAgents() {
        root.agentsEpoch++;
        togglePage("agents");
    }

    property string freezeShot: ""

    readonly property rect freezeBounds: {
        var xs = Quickshell.screens;
        if (!xs || xs.length === 0) return Qt.rect(0, 0, 0, 0);
        var minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity;
        for (var i = 0; i < xs.length; i++) {
            var s = xs[i];
            minx = Math.min(minx, s.x);
            miny = Math.min(miny, s.y);
            maxx = Math.max(maxx, s.x + s.width);
            maxy = Math.max(maxy, s.y + s.height);
        }
        return Qt.rect(minx, miny, maxx - minx, maxy - miny);
    }

    property string lastShotPath: ""
    Process { id: pShotSay }
    function shotCopied(path: string): void {
        root.lastShotPath = String(path);
        var name = String(path).split("/").pop();
        pShotSay.command = ["notify-send", "-a", "Panacea", "-i", String(path),
                            "-h", "int:transient:1",
                            root.tr("Screenshot"),
                            root.tr("Copied to the clipboard") + " · " + name];
        pShotSay.running = false;
        pShotSay.running = true;
        root.playSound("screenshot");
    }

    function sayToast(title, body) {
        pShotSay.command = ["notify-send", "-a", "Panacea",
                            "-h", "int:transient:1",
                            String(title), String(body)];
        pShotSay.running = false;
        pShotSay.running = true;
    }

    readonly property bool settingsMode:
        expanded && (page === "settings"
                     || page === "files" || page === "media")

    property bool wideSettings: false
    readonly property int settingsW: {
        var want = page === "files" ? Math.round((screen ? screen.width : 1920) * 0.78)
                 : page === "media" ? Math.round((screen ? screen.width : 1920) * 0.72)
                 : (wideSettings ? 1300 : 1040);
        var lim = (screen ? screen.width : 1920) - 80;
        return Math.min(want, lim);
    }

    property string themeFadeWall: ""
    property bool   themeFading: false

    FileView {
        id: curWallFile
        path: Quickshell.env("HOME") + "/.config/hypr/wallpaper.conf"
        blockLoading: true
    }

    function startThemeFade() {
        var m = /^\$wallpaper\s*=\s*(.+)$/m.exec(curWallFile.text() || "");
        if (!m) return;
        root.themeFadeWall = "file://" + String(m[1]).trim();
        root.themeFading = true;
    }
    function endThemeFade() { root.themeFading = false; }

    property string worldTarget: ""
    function applyWorld(id) {
        var w = Themes.of(id);
        if (w.id !== id || !w.world) return;
        if (root.expanded) root.collapse();
        if (id === root.cfg.themeId) return;
        root.worldTarget = id;
        pWorldSet.command = ["sh", "-c", "mkdir -p \"$HOME/.config/loka\" && printf '%s\\n' \"$1\" > \"$HOME/.config/loka/world\"; exec \"$HOME/.local/bin/rice\" world \"$1\"", "_", id];
        pWorldSet.running = true;
        root.cfg.themeId = id;
        root.cfg.fontFam = w.fonts[0];
        root.cfg.fontBody = w.fonts[1];
        root.cfg.fontDisplay = w.fonts[2];
        root.saveCfg();
    }
    function applyWorldWall(id, path) {
        var w = Themes.of(id);
        if (w.id !== id || !w.world) return;
        if (root.expanded) root.collapse();
        root.worldTarget = id;
        if (id !== root.cfg.themeId) {
            root.cfg.themeId = id;
            root.cfg.fontFam = w.fonts[0];
            root.cfg.fontBody = w.fonts[1];
            root.cfg.fontDisplay = w.fonts[2];
            root.saveCfg();
        }
        pWorldSet.command = ["sh", "-c", "mkdir -p \"$HOME/.config/loka\" && printf '%s\\n' \"$1\" > \"$HOME/.config/loka/world\"; exec \"$HOME/.local/bin/rice\" world \"$1\" \"$2\"", "_", id, path];
        pWorldSet.running = true;
    }
    function openWorldWalls(name) {
        if (root.expanded) root.collapse();
        worldWallsLoader.active = true;
        if (worldWallsLoader.item) worldWallsLoader.item.show(name || "");
        else root.worldWallsWanted = name || root.cfg.themeId;
    }
    property string worldWallsWanted: ""
    Process {
        id: pWorldSet
    }

    readonly property var stickyBox: ({ p: null })
    readonly property var player: {
        var list = Mpris.players ? Mpris.players.values : [];
        var playing = null, any = null, stickyAlive = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p) continue;
            if (!any) any = p;
            if (p === root.stickyBox.p) stickyAlive = p;
            if (p.isPlaying && !playing) playing = p;
        }
        return playing || stickyAlive || any;
    }
    onPlayerChanged: { if (player) root.stickyBox.p = player; refreshMediaArt(); }
    readonly property bool mediaActive:
        cfg.featPlayer
        && player !== null && player !== undefined
        && String(player.trackTitle).trim().length > 0

    property string mediaArt: ""
    property string mediaArtTrack: ""
    function refreshMediaArt() {
        if (!player) { return; }
        var title = String(player.trackTitle || "");
        var art = String(player.trackArtUrl || "");
        if (title.length === 0) return;
        if (title !== root.mediaArtTrack) {
            root.mediaArtTrack = title;
            root.mediaArt = art;
        } else if (art.length > 0) {
            root.mediaArt = art;
        }
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackArtUrlChanged() { root.refreshMediaArt(); }
        function onTrackTitleChanged()  { root.refreshMediaArt(); }
        function onPostTrackChanged()   { root.refreshMediaArt(); }
        function onIsPlayingChanged()   { root.refreshMediaArt(); }
    }

    readonly property var battDev: UPower.displayDevice

    readonly property int batteryPct:
        battDev && battDev.ready ? Math.round(battDev.percentage * 100) : 100

    readonly property bool batteryCharging:
        battDev && battDev.ready && battDev.state === UPowerDeviceState.Charging

    readonly property bool acOnline: !UPower.onBattery

    readonly property var battIcons: [
        0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E,
        0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]

    readonly property string batteryLevelIcon:
        String.fromCodePoint(battIcons[Math.max(0, Math.min(10, Math.round(batteryPct / 10)))])

    readonly property bool batteryPresent: {
        var list = UPower.devices ? UPower.devices.values : [];
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (d && d.ready && d.isLaptopBattery) return true;
        }
        return false;
    }

    readonly property int battLowThreshold: 15
    property bool battLowNotified: false

    function battLowCheck() {
        if (!root.batteryPresent) return;
        if (root.acOnline || root.batteryCharging || root.batteryPct > root.battLowThreshold + 5) {
            root.battLowNotified = false;
            root.battCritNotified = false;
            return;
        }
        if (root.batteryPct <= root.battLowThreshold && !root.battLowNotified) {
            root.battLowNotified = true;
            root.showBattLowToast();
        }
        if (root.batteryPct <= 5 && !root.battCritNotified) {
            root.battCritNotified = true;
            pBattCrit.command = ["notify-send", "-u", "critical", "-a", "Battery", "-i", "battery-caution",
                                 "Battery " + root.batteryPct + "%", "Plug in now. The laptop shuts down at 2% and unsaved work is lost."];
            pBattCrit.running = true;
        }
    }
    property bool battCritNotified: false
    Process { id: pBattCrit }
    Connections {
        target: root
        function onBatteryPctChanged()      { root.battLowCheck(); }
        function onAcOnlineChanged()        { root.battLowCheck(); }
        function onBatteryChargingChanged() { root.battLowCheck(); }
    }

    property string brightBackend: "none"
    property bool   hasTouchpad: false
    property bool   ddcutilPresent: false
    readonly property bool isLaptop: root.batteryPresent
    readonly property bool showBattery: root.batteryPresent
    readonly property bool showPowerProfiles: root.batteryPresent && root.cfg.featPowerProfiles

    Process {
        id: pMachine
        running: true
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.slice(text.lastIndexOf("backend="));
                t.trim().split("\n").forEach(function (line) {
                    var p = line.split("=");
                    if (p.length !== 2) return;
                    if (p[0] === "backend")  root.brightBackend  = p[1].trim();
                    if (p[0] === "touchpad") root.hasTouchpad    = p[1].trim() === "1";
                    if (p[0] === "ddcutil")  root.ddcutilPresent = p[1].trim() === "1";
                });
                root.brightRefresh(false);
            }
        }
    }

    property string weatherTemp: ""
    property string weatherFeels: ""
    property string weatherHumidity: ""
    property string weatherPressure: ""
    property string weatherWind: ""
    property string weatherClouds: ""
    property string weatherCond: ""
    property string weatherDesc: ""
    property string weatherIcon: ""
    property string weatherPlace: ""
    property string weatherErr: ""
    property bool   weatherBusy: false

    readonly property bool weatherReady:
        root.weatherErr.length === 0 && root.weatherTemp.length > 0
    readonly property string weatherUnitLetter:
        root.cfg.weatherUnits === "imperial" ? "F" : "C"
    readonly property string weatherWindUnit:
        root.cfg.weatherUnits === "imperial" ? "mph"
                                             : "m/s"

    readonly property string weatherGlyph: {
        var k = String(root.weatherIcon).slice(0, 2);
        return String.fromCodePoint(
              k === "01" ? 0xF0599
            : k === "02" ? 0xF0595
            : (k === "03" || k === "04") ? 0xF0590
            : (k === "09" || k === "10") ? 0xF0597
            : k === "11" ? 0xF0593
            : k === "13" ? 0xF0598
            : k === "50" ? 0xF0591
                         : 0xF0590);
    }

    Process {
        id: pWeather
        stdout: StdioCollector {
            onStreamFinished: {
                root.weatherBusy = false;
                var txt = String(text);
                var cut = txt.lastIndexOf("temp=");
                var errCut = txt.lastIndexOf("err=");
                if (errCut > cut) cut = errCut;
                if (cut > 0) txt = txt.slice(cut);

                var got = {};
                txt.trim().split("\n").forEach(function (line) {
                    var i = line.indexOf("=");
                    if (i > 0) got[line.slice(0, i)] = line.slice(i + 1).trim();
                });

                root.weatherErr = got["err"] || "";
                if (root.weatherErr.length) return;

                root.weatherTemp     = got["temp"]     || "";
                root.weatherFeels    = got["feels"]    || "";
                root.weatherHumidity = got["humidity"] || "";
                root.weatherPressure = got["pressure"] || "";
                root.weatherWind     = got["wind"]     || "";
                root.weatherClouds   = got["clouds"]   || "";
                root.weatherCond     = got["cond"]     || "";
                root.weatherDesc     = got["desc"]     || "";
                root.weatherIcon     = got["icon"]     || "";
                root.weatherPlace    = got["city"]     || "";
            }
        }
    }

    function refreshWeather() {
        if (!root.cfg.weatherCity.length) {
            root.weatherErr = "no-city";
            return;
        }
        root.weatherBusy = true;
        pWeather.command = ["sh", "-c",
            root.scriptDir + "/weather.sh \"$1\" \"$2\" \"$3\" \"$4\"", "_",
            String(root.cfg.weatherKey), String(root.cfg.weatherCity),
            String(root.cfg.weatherUnits), "en"];
        pWeather.running = false;
        pWeather.running = true;
        root.refreshWeatherForecast();
    }

    Timer {
        interval: 900000
        running: (root.cfg.featWidgets || root.cfg.weatherOnIsland)
                 && (root.cfg.weatherCity.length > 0 || root.cfg.weatherKey.length > 0)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }

    property bool weatherDetailsOpen: false
    property var  weatherForecastData: null

    Process {
        id: pWeatherForecast
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed && !parsed.err) {
                        root.weatherForecastData = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    function openWeatherDetails() {
        root.weatherDetailsOpen = true;
        root.refreshWeatherForecast();
    }

    function refreshWeatherForecast() {
        if (!root.cfg.weatherCity.length) return;
        pWeatherForecast.command = ["sh", "-c",
            root.scriptDir + "/weather_forecast.sh \"$1\" \"$2\" \"$3\" \"$4\"", "_",
            String(root.cfg.weatherKey), String(root.cfg.weatherCity),
            String(root.cfg.weatherUnits), "en"];
        pWeatherForecast.running = false;
        pWeatherForecast.running = true;
    }

    property int loadCpu:  -1
    property int loadMem:  -1
    property int loadGpu:  -1
    property int loadTempCpu: -1
    property int loadTempGpu: -1
    property int loadDisk: -1

    readonly property bool loadWanted: root.expanded || root.cfg.featWidgets || root.cfg.systemLoadOnIsland

    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded && root.loadWanted) {
                pLoad.running = false;
                pLoad.running = true;
            }
        }
    }

    Process {
        id: pLoad
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/sysload.sh" + ((root.expanded || root.cfg.systemLoadOnIsland) ? "" : " --fast")]
        stdout: StdioCollector {
            onStreamFinished: {
                var recs = String(text).trim().split("\n").filter(r => r.indexOf("|") >= 0);
                if (!recs.length) return;
                var a = recs[recs.length - 1].split("|");
                function num(s) {
                    s = String(s || "").trim();
                    return s.length ? (+s) : -1;
                }
                if (root.expanded || root.cfg.systemLoadOnIsland) {
                    root.loadCpu = num(a[0]);
                    root.loadMem = num(a[1]);
                    root.loadGpu = num(a[2]);
                    root.loadTempCpu = num(a[3]);
                    root.loadTempGpu = num(a[4]);
                    root.loadDisk = num(a[5]);
                } else {
                    root.loadMem = num(a[1]);
                    root.loadDisk = num(a[5]);
                }
            }
        }
    }

    Timer {
        interval: root.expanded ? 2000 : 5000
        running: root.loadWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: { pLoad.running = false; pLoad.running = true; }
    }

    property var brightList: []
    property bool brightBusy: false

    Process {
        id: pBrightList
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                text.trim().split("\n").forEach(function (line) {
                    var p = line.split("\t");
                    if (p.length < 3) return;
                    var pct = parseInt(p[2]);
                    if (isNaN(pct)) return;
                    out.push({ id: p[0], name: p[1], pct: pct });
                });
                root.brightList = out;
                root.brightBusy = false;
            }
        }
    }

    function brightRefresh(rescan) {
        if (root.brightBackend === "none") return;
        root.brightBusy = true;
        pBrightList.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh "
            + (rescan ? "rescan" : "list")];
        pBrightList.running = false;
        pBrightList.running = true;
    }

    Process { id: pBrightSet }
    property string brightPendingId: ""
    property int    brightPendingPct: -1

    Timer {
        id: brightFlush
        interval: 180
        repeat: false
        onTriggered: {
            if (root.brightPendingPct < 0) return;
            pBrightSet.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh set "
                + root.brightPendingId + " " + root.brightPendingPct];
            pBrightSet.running = false;
            pBrightSet.running = true;
            root.brightPendingPct = -1;
        }
    }

    function brightSet(id, pct) {
        pct = Math.max(1, Math.min(100, Math.round(pct)));
        var l = root.brightList.slice();
        for (var i = 0; i < l.length; i++)
            if (l[i].id === id) l[i] = { id: id, name: l[i].name, pct: pct };
        root.brightList = l;

        root.brightPendingId = id;
        root.brightPendingPct = pct;
        brightFlush.restart();
    }

    property var batteryDetails: ({})
    Process {
        id: batteryInfoProcess
        command: ["python3", root.scriptDir + "/battery-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.batteryDetails = JSON.parse(text); }
                catch (e) { root.batteryDetails = ({}); }
            }
        }
    }
    Timer {
        interval: 300000; repeat: true
        running: root.batteryPresent
        triggeredOnStart: true
        onTriggered: if (!batteryInfoProcess.running) batteryInfoProcess.running = true
    }
    function refreshBatteryDetails() {
        if (!batteryInfoProcess.running) batteryInfoProcess.running = true;
    }
    Process {
        id: batteryThresholdProcess
        onExited: (code, status) => {
            root.refreshBatteryDetails();
            if (code !== 0) root.sayToast(root.tr("Battery"), root.tr("Could not change the charge threshold"));
        }
    }
    function setBatteryThreshold(start, end) {
        var name = root.batteryDetails.name || "";
        if (!name || batteryThresholdProcess.running) return;
        batteryThresholdProcess.command = ["pkexec", "/usr/local/lib/panacea/panacea-root", "charge-threshold", name, String(start), String(end)];
        batteryThresholdProcess.running = true;
    }
    readonly property real batteryRemainingSeconds: battDev && battDev.ready
        ? (batteryCharging ? battDev.timeToFull : (!acOnline ? battDev.timeToEmpty : 0)) : 0

    readonly property real batteryHealth:
        battDev && battDev.ready ? Math.round(battDev.healthPercentage) : 0
    readonly property real batteryCapacity:
        battDev && battDev.ready ? battDev.energyCapacity : 0
    readonly property real batteryRate:
        battDev && battDev.ready ? battDev.changeRate : 0

    readonly property string batteryIcon: {
        if (batteryCharging) return String.fromCodePoint(0xF0241);
        var step = Math.max(0, Math.min(10, Math.round(batteryPct / 10)));
        return String.fromCodePoint(battIcons[step]);
    }

    property var authFlow: null
    readonly property bool authActive: authFlow !== null && !authFlow.isCompleted

    Loader {
        active: root.cfg.featPolkit
        sourceComponent: PolkitAgent {
            onAuthenticationRequestStarted: {
                root.authFlow = flow;
                pageResetTimer.stop();
                root.page = "auth";
                root.expanded = true;
                root.holdOpen = true;
            }
        }
    }

    Connections {
        target: root.authFlow
        ignoreUnknownSignals: true
        function onIsCompletedChanged() {
            if (root.authFlow && root.authFlow.isCompleted) {
                root.authFlow = null;
                root.collapse();
            }
        }
    }

    property bool keepAwake: false
    onKeepAwakeChanged: {
        pXset.command = root.keepAwake
            ? ["sh", "-c", "xset s off -dpms"]
            : ["sh", "-c", "xset s 600 600 +dpms dpms 0 0 900"];
        pXset.running = true;
    }
    Process {
        id: pXset
        command: ["sh", "-c", "xset s 600 600 +dpms dpms 0 0 900"]
        Component.onCompleted: running = true
    }
    Process {
        running: root.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep:handle-lid-switch",
                  "--who=Panacea", "--why=Keep awake", "sleep", "infinity"]
    }

    readonly property var audioSinks: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isSink && !n.isStream) out.push(n);
        }
        return out;
    }
    readonly property var audioStreams: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isStream && n.audio) {
                var props = n.properties || {};
                var name = String(props["application.name"] || props["media.name"] || n.name || "").toLowerCase();
                if (name.indexOf("cava") < 0 && name.indexOf("quickshell") < 0) {
                    out.push(n);
                }
            }
        }
        return out;
    }
    readonly property string sinkName: {
        var n = Pipewire.defaultAudioSink;
        if (!n) return "";
        return String(n.nickname || n.description || n.name || "");
    }
    function setSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    Process {
        running: root.cfg.featThemes
        command: ["sh", "-c", Quickshell.env("HOME")
                  + "/.config/panacea/scripts/thumbs.sh all"]
    }

    readonly property var trayItems: SystemTray.items

    property bool dnd: cfg.notifDnd
    function toggleDnd() { cfg.notifDnd = !cfg.notifDnd; root.saveCfg(); }
    property var  notifCurrent: null
    ListModel { id: notifModel }
    readonly property var notifications: notifModel
    readonly property bool hasNotifications: cfg.featNotifications
    property var notifServer: notifLoader.item
    Loader {
        id: notifLoader
        active: root.cfg.featNotifications
        sourceComponent: notifServerComp
    }
    readonly property var activeNotifications:
        notifServer ? notifServer.trackedNotifications : null

    property var notifObjs: ({})

    Process { id: pFocusApp }
    function focusApp(hint) {
        var h = String(hint || "").trim();
        if (h.length === 0) return;
        pFocusApp.running = false;
        pFocusApp.command = ["sh", "-c",
            root.scriptDir + "/focusapp.sh \"$1\"", "_", h];
        pFocusApp.running = true;
    }

    property bool hoverExpandArmed: true

    function activateNotification(what) {
        var n = null;
        var id = -1;
        if (what !== null && typeof what === "object") {
            n = what;
            id = Number(what.id);
        } else {
            id = Number(what);
            n = root.notifObjs[String(id)] || null;
        }
        var hint = "";
        if (n) {
            hint = String(n.desktopEntry || "") || String(n.appName || "");
            var acts = n.actions || [];
            var used = false;
            for (var i = 0; i < acts.length; i++) {
                if (String(acts[i].identifier) === "default") {
                    acts[i].invoke(); used = true; break;
                }
            }
            if (!used && acts.length === 1) acts[0].invoke();
        }
        if (id >= 0 && id === root.updNotifId) {
            root.updNotifId = -1;
            root.dismissToast();
            root.dropNotification(id);
            root.openSettingsAt("system");
            return;
        }

        if (root.lastShotPath.length > 0 && n && (String(n.summary || "").indexOf("Screenshot") >= 0
                                              || String(n.summary || "").indexOf("Screenshot") >= 0
                                              || (String(n.appName || "") === "Panacea" && String(n.image || "").indexOf(".png") >= 0))) {
            var shotToOpen = root.lastShotPath;
            root.dismissToast();
            if (id >= 0) root.dropNotification(id);
            root.openMedia(shotToOpen);
            return;
        }

        root.focusApp(hint);
        root.dismissToast();
        if (id >= 0) root.dropNotification(id);
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
        root.collapse();
    }

    readonly property bool toastActive: notifCurrent !== null && !expanded
    readonly property string notifSummary: notifCurrent ? String(notifCurrent.summary || "") : ""
    readonly property string notifBody:    notifCurrent ? String(notifCurrent.body || "") : ""
    readonly property string notifApp:     notifCurrent ? String(notifCurrent.appName || "") : ""
    readonly property string notifImage:   notifCurrent ? root.notifIconFor(notifCurrent) : ""

    function notifIconFor(n) {
        var img = String(n.image || "");
        if (img.length === 0) img = String(n.appIcon || "");
        if (img.length === 0) return "";
        if (img.indexOf("image://icon/") === 0)
            return Quickshell.iconPath(img.substring(13).split("?")[0], true);
        if (img.indexOf("/") >= 0 || img.indexOf(":") >= 0) return img;
        return Quickshell.iconPath(img, true);
    }
    readonly property bool   notifUrgent:
        notifCurrent ? notifCurrent.urgency === NotificationUrgency.Critical : false

    Component {
    id: notifServerComp
    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: n => {
            var app = String(n.appName || "");
            var sum = String(n.summary || "");
            if (/^Some required themes are missing/.test(sum)) { n.dismiss(); return; }
            if (app === "osd") {
                var tag = String((n.hints && n.hints["x-dunst-stack-tag"]) || "");
                var val = n.hints && n.hints["value"] !== undefined ? Number(n.hints["value"]) / 100 : -1;
                var kind = tag.indexOf("bri") >= 0 ? "bright" : tag.indexOf("mic") >= 0 ? "mic" : "vol";
                if (val >= 0) root.showOsd(kind, val, /mute/i.test(String(n.body || "")));
                n.dismiss();
                return;
            }
            n.tracked = true;

            if (/claude|codex|antigravity/i.test(app + " " + sum)) {
                var events = root.islandAgentEvents.slice();
                events.unshift({title: sum, body: String(n.body || ""), app: app});
                root.islandAgentEvents = events.slice(0, 20);
            }
            var isTransient = (app === "Panacea"
                               || sum === root.tr("Screenshot")
                               || sum === "Screenshot"
                               || sum === "Screenshot"
                               || sum.indexOf("Screenshot") >= 0
                               || sum.indexOf("Screenshot") >= 0);
            if (n.hints && (n.hints["transient"] === true || n.hints["transient"] === 1 || n.hints["transient"] === "1")) {
                isTransient = true;
            }

            if (!isTransient) {
                notifModel.insert(0, {
                    nId: Number(n.id),
                    nSummary: String(n.summary || ""),
                    nBody: String(n.body || ""),
                    nApp: String(n.appName || ""),
                    nImage: root.notifIconFor(n),
                    nUrgent: n.urgency === NotificationUrgency.Critical,
                    nTime: Qt.formatDateTime(new Date(), "HH:mm")
                });
                while (notifModel.count > 50) notifModel.remove(notifModel.count - 1);
            }

            var nid = Number(n.id);
            var objs = root.notifObjs;
            objs[String(nid)] = n;
            root.notifObjs = objs;
            n.closed.connect(function (reason) {
                var o = root.notifObjs;
                delete o[String(nid)];
                root.notifObjs = o;
                if (reason !== NotificationCloseReason.CloseRequested) return;
                root.dropNotification(nid);
            });

            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;

            root.enqueueToast(n);
        }
    }
    }

    property var toastQueue: []
    property double approvalToastEnd: 0
    property real approvalToastRemaining: 0
    readonly property bool approvalToast: notifCurrent !== null
        && String(notifCurrent.appName || "").indexOf("Panacea ") === 0
        && (notifCurrent.actions || []).some(a => String(a.identifier) === "panacea-allow")
    Timer {
        interval: 80; repeat: true; running: root.approvalToast
        onTriggered: root.approvalToastRemaining = Math.max(0, root.approvalToastEnd - Date.now())
    }
    function replyAgentApproval(actionId) {
        var n = root.notifCurrent;
        if (!root.approvalToast || !n || Date.now() >= root.approvalToastEnd) return;
        var actions = n.actions || [];
        for (var i = 0; i < actions.length; i++) {
            if (String(actions[i].identifier) === actionId) {
                actions[i].invoke(); root.dismissToast(); return;
            }
        }
    }

    function enqueueToast(n) {
        var q = root.toastQueue.slice();
        q.push({ notif: n, at: Date.now() });
        root.toastQueue = q;
        root.pumpToasts();
    }

    function pumpToasts() {
        if (root.notifCurrent !== null || root.expanded) return;
        if (root.toastQueue.length === 0) return;

        var q = root.toastQueue.slice();
        var item = q.shift();
        root.toastQueue = q;

        if (Date.now() - item.at > 60000) { root.pumpToasts(); return; }

        var n = item.notif;
        var isApproval = String(n.appName || "").indexOf("Panacea ") === 0
            && (n.actions || []).some(a => String(a.identifier) === "panacea-allow");
        if (isApproval && Date.now() - item.at >= 30000) { n.dismiss(); root.pumpToasts(); return; }
        root.notifCurrent = n;
        if (isApproval) { root.approvalToastEnd = item.at + 30000; root.approvalToastRemaining = root.approvalToastEnd - Date.now(); }
        var crit = n.urgency === NotificationUrgency.Critical;
        var want = crit ? root.cfg.notifCritTimeout : root.cfg.notifTimeout;
        var ms = n.expireTimeout > 0 ? (n.expireTimeout < 100 ? n.expireTimeout * 1000 : n.expireTimeout) : want;
        if (!crit && want > 0 && ms > want) ms = want;
        if (crit && want === 0) ms = 0;
        toastTimer.interval = isApproval ? Math.max(1, root.approvalToastEnd - Date.now()) : (ms > 0 ? Math.max(1000, ms) : 24 * 60 * 60 * 1000);
        toastTimer.restart();
    }

    Timer { id: toastPump; interval: 260; onTriggered: root.pumpToasts() }

    Timer {
        id: toastTimer
        onTriggered: {
            if (root.approvalToast) { if (root.notifCurrent) root.notifCurrent.dismiss(); root.dismissToast(); return; }
            if (capsuleHover.hovered) { toastTimer.interval = 1200; restart(); return; }
            root.dismissToast();
        }
    }
    function forgetNotification(index) {
        var e = notifModel.get(index);
        var nid = e ? Number(e.nId) : -1;
        notifModel.remove(index);
        if (nid < 0 || !notifServer) return;
        var live = notifServer.trackedNotifications.values;
        for (var i = 0; i < live.length; i++) {
            if (live[i] && Number(live[i].id) === nid) { live[i].dismiss(); break; }
        }
        if (root.notifCurrent && Number(root.notifCurrent.id) === nid) root.dismissToast();
    }

    function dropNotification(nid) {
        for (var i = 0; i < notifModel.count; i++) {
            if (Number(notifModel.get(i).nId) === nid) { notifModel.remove(i); break; }
        }
        var q = root.toastQueue.filter(function (it) {
            return !it.notif || Number(it.notif.id) !== nid;
        });
        if (q.length !== root.toastQueue.length) root.toastQueue = q;

        if (root.notifCurrent && Number(root.notifCurrent.id) === nid) root.dismissToast();
    }

    function dismissToast() {
        toastTimer.stop();
        root.notifCurrent = null;
        toastPump.restart();
    }
    function clearNotifications() {
        notifModel.clear();
        if (!notifServer) return;
        var live = notifServer.trackedNotifications.values;
        for (var i = live.length - 1; i >= 0; i--) {
            if (live[i]) live[i].dismiss();
        }
    }

    property bool   vaultUnlocked: false
    property string vaultKey: ""
    property var    vaultEntries: []
    property string vaultError: ""
    property bool   vaultBusy: false
    readonly property int vaultIdleMs: 15 * 60 * 1000

    Timer {
        id: vaultIdle
        interval: root.vaultIdleMs
        onTriggered: root.lockVault()
    }
    function touchVault() { if (root.vaultUnlocked) vaultIdle.restart(); }

    property bool vaultLockPending: false
    function finishLockVault() {
        root.vaultLockPending = false;
        root.vaultKey = "";
        root.vaultEntries = [];
    }
    function lockVault() {
        vaultIdle.stop();
        root.vaultUnlocked = false;
        root.vaultError = "";
        if (root.vaultDirty || pVaultSave.running) {
            root.vaultLockPending = true;
            vaultSaveTimer.restart();
            return;
        }
        finishLockVault();
    }

    PamContext {
        id: vaultPam
        config: "swaylock"
        onPamMessage: {
            if (responseRequired) respond(root.vaultKey);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.vaultLoad();
            } else {
                root.vaultKey = "";
                root.vaultBusy = false;
                root.vaultError = root.tr("Wrong password");
            }
        }
    }

    function unlockVault(password) {
        if (root.vaultBusy) return;
        root.vaultError = "";
        root.vaultKey = String(password || "");
        if (root.vaultKey.length === 0) return;
        root.vaultBusy = true;
        if (!vaultPam.start()) {
            root.vaultBusy = false;
            root.vaultKey = "";
            root.vaultError = root.tr("Could not verify the password");
        }
    }

    Process {
        id: pVaultLoad
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.length === 0) return;
                try { root.vaultEntries = JSON.parse(t); } catch (e) { root.vaultEntries = []; }
            }
        }
        onExited: code => {
            root.vaultBusy = false;
            if (code === 0) {
                root.vaultUnlocked = true;
                vaultIdle.restart();
                root.vaultError = "";
            } else {
                root.vaultKey = "";
                root.vaultError = code === 2 ? root.tr("The vault did not open")
                                             : root.tr("Vault error");
            }
        }
    }
    function vaultLoad() {
        pVaultLoad.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/vault.sh load"];
        pVaultLoad.running = true;
        pVaultLoad.write(root.vaultKey + "\n");
        pVaultLoad.stdinEnabled = false;
    }

    Process {
        id: pVaultSave
        stdinEnabled: true
        onExited: code => {
            if (code !== 0) root.vaultError = root.tr("Could not save");
            if (root.vaultDirty) vaultSaveTimer.restart();
            else if (root.vaultLockPending) root.finishLockVault();
        }
    }

    property bool vaultDirty: false
    Timer {
        id: vaultSaveTimer
        interval: 120
        onTriggered: root.vaultFlush()
    }
    function vaultSave() {
        if (!root.vaultUnlocked) return;
        touchVault();
        root.vaultDirty = true;
        vaultSaveTimer.restart();
    }
    function vaultFlush() {
        if (root.vaultKey.length === 0) return;
        if (pVaultSave.running) { vaultSaveTimer.restart(); return; }
        root.vaultDirty = false;
        pVaultSave.stdinEnabled = true;
        pVaultSave.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/vault.sh save"];
        pVaultSave.running = true;
        pVaultSave.write(root.vaultKey + "\n" + JSON.stringify(root.vaultEntries));
        pVaultSave.stdinEnabled = false;
    }

    function vaultAdd(label, login, pw) {
        if (!root.vaultUnlocked) return;
        var a = root.vaultEntries.slice();
        a.unshift({
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 1e6),
            label: String(label || root.tr("Untitled")),
            login: String(login || ""),
            pw: String(pw || ""),
            at: Qt.formatDateTime(new Date(), "dd.MM.yyyy HH:mm")
        });
        root.vaultEntries = a;
        vaultSave();
    }
    function vaultUpdate(id, label, login, pw) {
        var a = root.vaultEntries.slice();
        for (var i = 0; i < a.length; i++) {
            if (a[i].id !== id) continue;
            a[i] = { id: id, label: String(label), login: String(login),
                     pw: String(pw), at: a[i].at };
            break;
        }
        root.vaultEntries = a;
        vaultSave();
    }
    function vaultRemove(id) {
        root.vaultEntries = root.vaultEntries.filter(function (e) { return e.id !== id; });
        vaultSave();
    }
    function vaultHas(pw) {
        for (var i = 0; i < root.vaultEntries.length; i++)
            if (root.vaultEntries[i].pw === pw) return true;
        return false;
    }

    property var    browserFound: []
    property bool   browserScanning: false
    property bool   browserScanned: false
    property string browserError: ""

    function browserScan() {
        if (!root.vaultUnlocked || root.browserScanning) return;
        root.browserError = "";
        root.browserFound = [];
        root.browserScanning = true;
        pBrowserScan.running = true;
    }

    Process {
        id: pBrowserScan
        command: ["python3", root.scriptDir + "/browser_pw.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = [];
                try { a = JSON.parse(text); } catch (e) { a = []; }
                root.browserFound = a.filter(function (e) {
                    return String(e.pw || "").length > 0 && !root.vaultHas(String(e.pw));
                });
                root.browserScanning = false;
                root.browserScanned = true;
                root.touchVault();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length) root.browserError = text.trim()
        }
        onExited: (code, status) => {
            root.browserScanning = false;
            root.browserScanned = true;
            if (code !== 0 && root.browserError.length === 0)
                root.browserError = root.tr("Could not read the browsers");
        }
    }

    function browserImport(item) {
        if (!root.vaultUnlocked || !item) return;
        root.vaultAdd(String(item.url || item.browser || root.tr("From a browser")),
                      String(item.login || ""), String(item.pw || ""));
        root.browserFound = root.browserFound.filter(function (e) {
            return !(e.pw === item.pw && e.login === item.login && e.url === item.url);
        });
    }

    function browserImportAll() {
        if (!root.vaultUnlocked) return;
        var list = root.browserFound.slice();
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            if (root.vaultHas(String(e.pw))) continue;
            root.vaultAdd(String(e.url || e.browser || root.tr("From a browser")),
                          String(e.login || ""), String(e.pw || ""));
        }
        root.browserFound = [];
    }

    property var vaultPrompt: null

    function looksLikePassword(s) {
        if (!root.cfg.featVault || !root.cfg.vaultCapture) return false;
        if (!s || s.length < 8 || s.length > 128) return false;
        if (/\s/.test(s)) return false;
        if (/^(https?|ftp|file|magnet):/i.test(s)) return false;
        if (s.indexOf("/") === 0 || s.indexOf("~/") === 0) return false;
        if (/^[0-9]+$/.test(s)) return false;
        if (/^[a-z]+$/.test(s)) return false;
        if (/@[^@]+\.[a-z]{2,}$/i.test(s)) return false;
        var classes = 0;
        if (/[a-z]/.test(s)) classes++;
        if (/[A-Z]/.test(s)) classes++;
        if (/[0-9]/.test(s)) classes++;
        if (/[^A-Za-z0-9]/.test(s)) classes++;
        return classes >= 3;
    }

    Process {
        id: pClipWatch
        running: root.cfg.featVault
        command: ["sh", "-c",
            "wl-paste --type text --watch sh -c "
            + "'printf \"%s\\n\" \"$(wl-paste -n -t text 2>/dev/null | head -1)\"'"]
        stdout: SplitParser {
            onRead: line => {
                var s = String(line);
                if (!root.looksLikePassword(s)) return;
                if (root.vaultUnlocked && root.vaultHas(s)) return;
                if (root.vaultPrompt && root.vaultPrompt.pw === s) return;
                root.vaultPrompt = { pw: s, label: "" };
                pVaultWhere.running = true;
                root.togglePage("vaultsave");
            }
        }
    }
    Process {
        id: pVaultWhere
        command: ["sh", "-c",
            "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then "
            + "niri msg --json focused-window 2>/dev/null | jq -r '.app_id // \"\"'; "
            + "else hyprctl activewindow -j 2>/dev/null | jq -r '.initialClass // .class // \"\"'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = text.trim();
                if (c.length === 0 || !root.vaultPrompt) return;
                root.vaultPrompt = { pw: root.vaultPrompt.pw,
                                     label: c.charAt(0).toUpperCase() + c.slice(1) };
            }
        }
    }
    Process { id: pVaultCopy }
    function vaultCopy(pw) {
        touchVault();
        pVaultCopy.command = ["sh", "-c",
            "printf '%s' \"$1\" | wl-copy --sensitive-data 2>/dev/null "
            + "|| printf '%s' \"$1\" | wl-copy", "_", String(pw)];
        pVaultCopy.running = true;
        vaultClipClear.restart();
    }
    Process { id: pVaultClip; command: ["sh", "-c", "wl-copy --clear"] }
    Timer { id: vaultClipClear; interval: 60000; onTriggered: pVaultClip.running = true }

    function dismissVaultPrompt() {
        root.vaultPrompt = null;
        if (root.page === "vaultsave") root.collapse();
    }

    property string osdKind: ""
    property real   osdValue: 0
    property bool   osdMuted: false
    readonly property bool osdActive: osdKind.length > 0 && !expanded

    Timer {
        id: osdTimer
        interval: 1700
        onTriggered: root.osdKind = ""
    }
    function showOsd(kind, value, muted) {
        if (!cfg.featOsd) return;
        osdKind = kind;
        osdValue = Math.max(0, Math.min(1, value));
        osdMuted = muted === true;
        osdTimer.restart();
    }

    readonly property string osdIcon: {
        if (osdKind === "bright") return String.fromCodePoint(0xF00DE);
        if (osdKind === "mic")
            return String.fromCodePoint(osdMuted ? 0xF036D : 0xF036C);
        if (osdMuted || osdValue <= 0.001) return String.fromCodePoint(0xF075F);
        if (osdValue < 0.34) return String.fromCodePoint(0xF057F);
        if (osdValue < 0.67) return String.fromCodePoint(0xF0580);
        return String.fromCodePoint(0xF057E);
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property var sinkAudio:
        Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var srcAudio:
        Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    property bool osdReady: false
    Timer { interval: 1500; running: true; onTriggered: root.osdReady = true }

    property bool sinkSwitching: false
    onSinkAudioChanged: { root.sinkSwitching = true; sinkSettleTimer.restart(); }
    Timer { id: sinkSettleTimer; interval: 700; onTriggered: root.sinkSwitching = false }

    Connections {
        target: root.sinkAudio
        enabled: root.sinkAudio !== null
        function onVolumeChanged() {
            if (root.osdReady && !root.sinkSwitching)
                root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
        }
        function onMutedChanged() {
            if (root.osdReady && !root.sinkSwitching)
                root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
        }
    }
    Connections {
        target: root.srcAudio
        enabled: root.srcAudio !== null
        function onMutedChanged() {
            if (root.osdReady) root.showOsd("mic", root.srcAudio.volume, root.srcAudio.muted);
        }
    }

    readonly property string powerScript:
        Quickshell.env("HOME") + "/.config/panacea/scripts/power.sh"

    property string powerProfile: "balanced"

    Process {
        id: pPowerGet
        command: ["sh", "-c", root.powerScript + " get"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (s.length) root.powerProfile = s;
            }
        }
    }
    Process {
        id: pPowerSet
        onRunningChanged: if (!running) pPowerGet.running = true
    }
    Timer {
        interval: root.expanded ? 10000 : 120000
        running: true; repeat: true
        onTriggered: pPowerGet.running = true
    }

    readonly property string profileLabel:
        powerProfile === "power-saver" ? tr("Power saver")
      : powerProfile === "performance" ? tr("Performance")
                                       : tr("Balanced")

    function setPowerProfile(name) {
        if (pPowerSet.running) return;
        pPowerSet.command = ["bash", root.powerScript, "set", name];
        pPowerSet.running = true;
    }

    readonly property int wsId:
        !Compositor.isHyprland ? Compositor.focusedWorkspace
                          : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    readonly property var wsRaw: {
        var out = [];
        if (!Compositor.isHyprland) {
            var nws = Compositor.workspaces;
            for (var k = 0; k < nws.length; k++)
                if (nws[k] && nws[k].id > 0) out.push(nws[k].id);
            out.sort(function (a, b) { return a - b; });
            return out;
        }
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < all.length; i++)
            if (all[i] && all[i].id > 0) out.push(all[i].id);
        out.sort(function (a, b) { return a - b; });
        return out;
    }

    property var wsList: []
    onWsRawChanged: {
        var a = root.wsRaw, b = root.wsList;
        if (a.length === b.length) {
            var same = true;
            for (var i = 0; i < a.length; i++)
                if (a[i] !== b[i]) { same = false; break; }
            if (same) return;
        }
        root.wsList = a;
    }

    property string kbLayout: Compositor.keyboardLayout
    Process {
        id: pKbLayout
        command: ["sh", "-c",
            "hyprctl devices -j | jq -r '.keyboards[]|select(.main==true)|.active_keymap' | head -1"]
        running: !Compositor.isNiri
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (!s.length) return;
                Compositor.keyboardLayoutName = s;
            }
        }
    }
    Connections {
        target: Hyprland
        enabled: Compositor.isHyprland
        function onRawEvent(ev) {
            if (ev.name === "activelayout") pKbLayout.running = true;
        }
    }

    property string timeText: ""
    property string dayText: ""
    property string dateLong: ""
    property string secText: ""
    property int timeHour: 0
    property int timeMinute: 0
    property int timeSecond: 0
    property string dayNum: ""
    property bool   weekend: false
    property string monthText: ""
    Timer {
        id: clockTick
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            clockTick.interval = (root.expanded || root.cfg.clockSeconds) ? 1000 - d.getMilliseconds() + 5 : 60000 - d.getSeconds() * 1000 - d.getMilliseconds() + 20;
            root.timeHour = d.getHours();
            root.timeMinute = d.getMinutes();
            root.timeSecond = d.getSeconds();
            var hr = d.getHours();
            var hr12 = (hr % 12) === 0 ? 12 : (hr % 12);
            var mm = ("0" + d.getMinutes()).slice(-2);
            var secStr = root.cfg.clockSeconds ? (":" + ("0" + d.getSeconds()).slice(-2)) : "";
            var ampm = hr >= 12 ? "PM" : "AM";
            root.timeText = root.cfg.clock12
                ? (hr12 + ":" + mm + secStr + " " + ampm)
                : Qt.formatDateTime(d, "HH:mm" + (root.cfg.clockSeconds ? ":ss" : ""));
            root.secText = Qt.formatDateTime(d, "ss");
            var dateLocale = Qt.locale("en_US");
            root.dateLong = (root.cfg.clockWeekday ? d.toLocaleDateString(dateLocale, "dddd") + ", " : "")
                + d.toLocaleDateString(dateLocale, root.cfg.clockDateFmt || "d MMMM");
            root.dayText = dateLocale.dayName(d.getDay(), Locale.ShortFormat);
            root.dayNum = String(d.getDate());
            root.weekend = d.getDay() === 0 || d.getDay() === 6;
            root.monthText = dateLocale.monthName(d.getMonth(), Locale.LongFormat);
        }
    }

    readonly property string wifiScript: Quickshell.env("HOME") + "/.config/panacea/scripts/wifi.sh"

    property bool wifiOn: true
    property string wifiSsid: ""
    property int wifiQuality: 0
    property bool wifiBusy: false
    property string wifiError: ""
    property string wifiConnectingSsid: ""
    property bool   wifiConnecting: false

    property bool   wifiToastShown: false
    property string wifiToastSsid: ""
    property int    wifiToastQuality: 0
    property bool   wifiToastDisconnected: false
    readonly property bool wifiToastActive:
        wifiToastShown && !expanded && !btToastActive && !acToastActive
    property string wifiPrevConnected: ""
    property string wifiLastSsid: ""
    property bool   wifiInitDone: false

    Timer {
        id: wifiInitTimer
        interval: 3500
        running: true
        onTriggered: {
            root.wifiPrevConnected = root.wifiSsid;
            if (root.wifiSsid.length > 0) root.wifiLastSsid = root.wifiSsid;
            root.wifiInitDone = true;
        }
    }

    onWifiSsidChanged: {
        if (!root.wifiInitDone) return;
        var ssid = root.wifiSsid;
        if (ssid.length > 0 && ssid !== root.wifiPrevConnected) {
            root.wifiPrevConnected = ssid;
            root.wifiLastSsid = ssid;
            root.wifiConnecting = false;
            root.wifiConnectingSsid = "";
            root.showWifiToast(ssid, root.wifiQuality, false);
            root.checkCaptive(ssid);
        } else if (ssid.length === 0) {
            root.wifiPrevConnected = "";
            root.wifiConnectingSsid = "";
        }
    }

    function checkCaptive(ssid) {
        pCaptive.running = false;
        pCaptive.command = ["sh", "-c", root.scriptDir + "/captive.sh \"$1\"", "_", ssid];
        pCaptive.environment = {
            PANACEA_CAPTIVE_TITLE: root.tr("Network sign-in required"),
            PANACEA_CAPTIVE_BODY: root.tr("Open the sign-in page to get internet access"),
            PANACEA_CAPTIVE_BTN: root.tr("Sign in")
        };
        captiveDelay.restart();
    }
    Timer { id: captiveDelay; interval: 2500; onTriggered: pCaptive.running = true }
    Process { id: pCaptive }

    onWifiOnChanged: {
        if (!root.wifiInitDone) return;
        if (root.wifiOn && root.wifiSsid.length === 0) {
            root.wifiConnecting = true;
            wifiSettleTimer.begin();
        } else if (!root.wifiOn) {
            root.wifiConnecting = false;
            root.wifiSsid = "";
            root.wifiPrevConnected = "";
            root.wifiConnectingSsid = "";
            wifiSettleTimer.stop();
        }
    }

    function showWifiToast(ssid, quality, isDisconnect) {
        root.wifiToastSsid = ssid;
        root.wifiToastQuality = quality || root.wifiQuality || 0;
        root.wifiToastDisconnected = isDisconnect || false;
        root.wifiToastShown = true;
        if (root.expanded && !root.holdOpen) root.collapse();
        wifiToastTimer.interval = 2500;
        wifiToastTimer.restart();
        root.playSound(isDisconnect ? "disconnect" : "connect");
    }

    function dismissWifiToast() {
        root.wifiToastShown = false;
        wifiToastTimer.stop();
    }
    Timer {
        id: wifiToastTimer
        interval: 2500
        onTriggered: root.dismissWifiToast()
    }

    ListModel { id: wifiModel }
    readonly property var wifiNetworks: wifiModel

    Process {
        id: pWifiStatus
        command: ["sh", "-c", root.wifiScript + " status"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                root.wifiOn = (p[0] === "on");
                var newSsid = p[1] || "";
                root.wifiQuality = parseInt(p[2]) || 0;
                root.wifiSsid = newSsid;
                if (newSsid.length > 0) {
                    root.wifiLastSsid = newSsid;
                    root.wifiConnecting = false;
                    root.wifiConnectingSsid = "";
                    wifiSettleTimer.stop();
                    wifiSettleTimer.tries = 0;
                }
            }
        }
    }
    function refreshWifiStatus() {
        pWifiStatus.running = false;
        pWifiStatus.running = true;
    }
    Timer {
        interval: root.expanded ? 4000 : 15000
        running: true; repeat: true
        onTriggered: root.refreshWifiStatus()
    }

    Process {
        id: pWifiList
        command: ["sh", "-c", root.wifiScript + " list"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 5) return;
                wifiModel.append({
                    connected: p[0] === "yes",
                    ssid: p[1],
                    security: p[2],
                    quality: parseInt(p[3]) || 0,
                    known: p[4] === "yes"
                });
            }
        }
        onRunningChanged: if (!running) root.wifiBusy = false
    }

    Process { id: pWifiScan; command: ["sh", "-c", root.wifiScript + " scan"] }
    Process {
        id: pWifiToggle
        command: ["sh", "-c", root.wifiScript + " toggle"]
        onRunningChanged: if (!running) {
            root.refreshWifiStatus();
            if (root.wifiOn) {
                wifiSettleTimer.begin();
            }
        }
    }
    Process {
        id: pWifiConnect
        onRunningChanged: {
            if (running) return;
            root.wifiBusy = false;
            if (exitCode !== 0) {
                root.wifiError = "Could not connect";
                root.wifiConnectingSsid = "";
                root.wifiConnecting = false;
            } else {
                root.wifiError = "";
                if (root.wifiConnectingSsid.length > 0) {
                    root.wifiSsid = root.wifiConnectingSsid;
                }
                root.page = "main";
            }
            root.refreshWifiStatus();
            wifiSettleTimer.begin();
            root.refreshWifiList();
        }
    }

    Timer {
        id: wifiSettleTimer
        interval: 800
        repeat: true
        property int tries: 0
        onTriggered: {
            root.refreshWifiStatus();
            if (root.wifiSsid.length > 0 || ++wifiSettleTimer.tries > 15) {
                root.wifiConnecting = false;
                if (root.wifiSsid.length > 0) {
                    root.wifiConnectingSsid = "";
                }
                wifiSettleTimer.tries = 0;
                wifiSettleTimer.stop();
            }
        }
        function begin() { wifiSettleTimer.tries = 0; wifiSettleTimer.restart(); }
    }

    Process { id: pWifiDisconnect }
    function disconnectWifi() {
        pWifiDisconnect.running = false;
        pWifiDisconnect.command = ["sh", "-c", root.wifiScript + " disconnect"];
        pWifiDisconnect.running = true;
        root.wifiConnecting = false;
        root.wifiSsid = "";
        root.wifiPrevConnected = "";
        root.wifiConnectingSsid = "";
        wifiSettleTimer.begin();
    }
    Process { id: pWifiForget }
    function forgetWifi(ssid) {
        if (!ssid || !ssid.length) return;
        if (root.wifiLastSsid === ssid) root.wifiLastSsid = "";
        pWifiForget.running = false;
        pWifiForget.command = ["sh", "-c", root.wifiScript + " forget \"$1\"", "_", String(ssid)];
        pWifiForget.running = true;
        wifiSettleTimer.begin();
        wifiRescanTimer.restart();
    }

    function toggleWifi() {
        if (root.wifiOn) {
            if (root.wifiSsid.length > 0) root.wifiLastSsid = root.wifiSsid;
            root.wifiOn = false;
            root.wifiConnecting = false;
            root.wifiSsid = "";
            root.wifiPrevConnected = "";
            root.wifiConnectingSsid = "";
            wifiSettleTimer.stop();
        } else {
            root.wifiOn = true;
            root.wifiConnecting = true;
            root.wifiConnectingSsid = "";
            wifiSettleTimer.begin();
        }
        pWifiToggle.running = false;
        pWifiToggle.running = true;
    }
    function refreshWifiList() {
        wifiModel.clear();
        root.wifiBusy = true;
        pWifiList.running = true;
    }
    function scanWifi() {
        root.wifiBusy = true;
        pWifiScan.running = true;
        wifiRescanTimer.restart();
    }
    Timer { id: wifiRescanTimer; interval: 2600; onTriggered: root.refreshWifiList() }

    function connectWifi(ssid, password, username, security) {
        root.wifiConnectingSsid = ssid;
        root.wifiBusy = true;
        root.wifiError = "";
        pWifiConnect.command = security === "eap"
            ? ["sh", "-c", root.wifiScript + " connect \"$1\" \"$2\" \"$3\" eap", "_", ssid, password, username]
            : password && password.length
            ? ["sh", "-c", root.wifiScript + " connect \"$1\" \"$2\"", "_", ssid, password]
            : ["sh", "-c", root.wifiScript + " connect \"$1\"", "_", ssid];
        pWifiConnect.running = true;
    }

    property bool   recActive: false
    property bool   recPaused: false
    property int    recStarted: 0
    property int    recPausedTotal: 0
    property string recFile: ""
    property string recError: ""
    property int    recNow: 0

    readonly property int recSeconds:
        recActive ? Math.max(0, recNow - recStarted - recPausedTotal) : 0
    readonly property string recTimeText: {
        var s = recSeconds;
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
        var mm = (m < 10 ? "0" : "") + m, ss = (x < 10 ? "0" : "") + x;
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss;
    }

    readonly property string recScript: root.scriptDir + "/record.sh"

    property string busyLabel: ""
    property int    busyProgress: -1
    property string busyGlyph: ""

    function beginBusy(label, glyph, progress) {
        root.busyLabel = label;
        root.busyGlyph = glyph;
        root.busyProgress = progress === undefined ? -1 : progress;
    }
    function endBusy() {
        root.busyLabel = "";
        root.busyGlyph = "";
        root.busyProgress = -1;
    }

    property var fileOpQueue: []
    property bool   fileOpActive: false
    property string fileOpLabel: ""
    property string fileOpFile: ""
    property string fileOpPhase: ""
    property real   fileOpDone: 0
    property real   fileOpTotal: 0
    property int    fileOpPct: 0
    property real   fileOpSpeed: 0
    property real   fileOpSyncLeft: 0
    property string fileOpError: ""
    property bool   fileOpCancelled: false
    property real   _fileOpT: 0
    property real   _fileOpD: 0

    function runFileOp(args, label) {
        if (pFileOp.running) {
            var q = root.fileOpQueue.slice();
            q.push({ args: args, label: label });
            root.fileOpQueue = q;
            return;
        }
        root._startFileOp(args, label);
    }
    function _startFileOp(args, label) {
        root.fileOpLabel = label || "";
        root.fileOpFile = "";
        root.fileOpPhase = "";
        root.fileOpDone = 0;
        root.fileOpTotal = 0;
        root.fileOpPct = 0;
        root.fileOpSpeed = 0;
        root.fileOpSyncLeft = 0;
        root.fileOpError = "";
        root.fileOpCancelled = false;
        root._fileOpT = Date.now();
        root._fileOpD = 0;
        root.fileOpActive = true;
        root.beginBusy(label, "󰆏", 0);
        var a = args.slice();
        if (a[0] === "sh" && a[1] === "-c" && String(a[2]).indexOf("exec ") !== 0)
            a[2] = "exec " + a[2];
        pFileOp.command = a;
        pFileOp.running = true;
    }
    function cancelFileOp() {
        root.fileOpQueue = [];
        if (pFileOp.running) pFileOp.signal(15);
    }
    function dismissFileOp() { root.fileOpError = ""; }

    function fileOpErrorText(code, rest) {
        switch (code) {
            case "no-space": return root.tr("Not enough space on the drive");
            case "no-write": return root.tr("No permission to write to this folder");
            case "no-dir":   return root.tr("Destination folder not found");
            case "into-self":return root.tr("Can't put a folder inside itself");
            case "fat-4g":   return root.tr("Files over 4 GB don't fit on FAT32: ") + rest;
            case "busy":     return root.tr("Drive is busy — close files opened from it");
        }
        return root.tr("Error: ") + rest;
    }

    Process {
        id: pFileOp
        stdout: SplitParser {
            onRead: line => {
                var t = String(line).trim();
                var m = /^PROGRESS (\d+)(?: (\d+) (\d+))?$/.exec(t);
                if (m) {
                    root.fileOpPct = parseInt(m[1], 10);
                    root.busyProgress = root.fileOpPct;
                    if (m[2] !== undefined) {
                        var d = parseFloat(m[2]), now = Date.now();
                        root.fileOpTotal = parseFloat(m[3]);
                        var dt = (now - root._fileOpT) / 1000;
                        if (dt >= 0.5) {
                            var inst = Math.max(0, (d - root._fileOpD) / dt);
                            root.fileOpSpeed = root.fileOpSpeed > 0
                                ? root.fileOpSpeed * 0.7 + inst * 0.3 : inst;
                            root._fileOpT = now;
                            root._fileOpD = d;
                        }
                        root.fileOpDone = d;
                    }
                    return;
                }
                if (t.indexOf("FILE ") === 0) { root.fileOpFile = t.substring(5); return; }
                if (t === "PHASE sync") { root.fileOpPhase = "sync"; return; }
                m = /^SYNC (\d+) (\d+)$/.exec(t);
                if (m) { root.fileOpSyncLeft = parseFloat(m[2]); return; }
                if (t === "CANCELLED") { root.fileOpCancelled = true; return; }
                if (t.indexOf("ERROR ") === 0) {
                    var parts = t.substring(6).split(" ");
                    root.fileOpError = root.fileOpErrorText(parts[0], parts.slice(1).join(" "));
                }
            }
        }
        onRunningChanged: {
            if (running) return;
            root.filesChanged();
            if (root.fileOpQueue.length > 0 && !root.fileOpError.length) {
                var q = root.fileOpQueue.slice();
                var next = q.shift();
                root.fileOpQueue = q;
                root._startFileOp(next.args, next.label);
                return;
            }
            root.fileOpActive = false;
            root.endBusy();
        }
    }

    property var    filesClipPaths: []
    property string filesClipMode: ""
    function setFilesClip(paths, mode) {
        root.filesClipPaths = paths;
        root.filesClipMode = mode;
        var uris = paths.map(function (p) { return "file://" + String(p).split("/").map(encodeURIComponent).join("/"); }).join("\r\n");
        pClipOut.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy --type text/uri-list", "_", uris];
        pClipOut.running = false;
        pClipOut.running = true;
    }
    Process { id: pClipOut }

    signal disksChanged()
    Process {
        id: pUdev
        running: root.cfg.featFiles
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        stdout: SplitParser {
            onRead: line => {
                var t = String(line);
                if (t.indexOf(" add ") >= 0 || t.indexOf(" change ") >= 0) udevMount.restart();
                if (t.indexOf("UDEV") === 0) udevKick.restart();
            }
        }
        onRunningChanged: if (!running) udevRestart.start()
    }
    Timer { id: udevRestart; interval: 3000; onTriggered: pUdev.running = true }
    Timer { id: udevKick; interval: 250; onTriggered: root.disksChanged() }
    Timer {
        id: udevMount
        interval: 700
        onTriggered: { pAutomount.running = false; pAutomount.running = true; }
    }
    Process {
        id: pAutomount
        command: ["sh", "-c", root.scriptDir + "/files.sh automount"]
        onRunningChanged: if (!running) root.disksChanged()
    }

    Process {
        id: pRecStatus
        command: ["sh", "-c", root.recScript + " status"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p[0] === "idle") {
                    root.recActive = false;
                    root.recPaused = false;
                    return;
                }
                root.recActive = true;
                root.recPaused = (p[0] === "paused");
                root.recStarted = parseInt(p[2]) || 0;
                root.recPausedTotal = parseInt(p[3]) || 0;
                root.recFile = p[4] || "";
            }
        }
    }
    Timer {
        interval: root.recActive ? 1000 : 30000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            root.recNow = Math.floor(Date.now() / 1000);
            pRecStatus.running = true;
        }
    }

    Process {
        id: pRecCmd
        onRunningChanged: if (!running) pRecStatus.running = true
        stderr: SplitParser {
            onRead: line => {
                var t = line.trim();
                if (!t.length) return;
                root.recError = t === "already" ? root.tr("Already recording")
                              : t === "no-recorder" ? root.tr("ffmpeg not found")
                              : t === "failed"  ? root.tr("Could not start recording")
                                                : t;
                recErrorClear.restart();
            }
        }
    }
    Timer { id: recErrorClear; interval: 4000; onTriggered: root.recError = "" }

    property bool recPick: false
    property var  recPickMons: []
    readonly property bool recPickActive: recPick && !expanded

    function startRecord() {
        if (root.recActive) return;
        root.recError = "";
        var scr = Quickshell.screens;
        if (scr && scr.length > 1) {
            var list = [];
            for (var i = 0; i < scr.length; i++)
                list.push({ name: scr[i].name,
                            desc: String(scr[i].model || scr[i].name) });
            root.recPickMons = list;
            root.recPick = true;
            if (root.expanded) root.collapse();
            return;
        }
        root.startRecordOn(scr && scr.length ? scr[0].name : "");
    }
    function startRecordOn(output) {
        root.recPick = false;
        root.recError = "";
        pRecCmd.command = ["sh", "-c",
            root.recScript + " start \"$1\" \"$2\" \"$3\" \"$4\" \"$5\" \"$6\"", "_",
            String(root.cfg.recFps), String(root.cfg.recDir),
            root.cfg.recSysAudio ? "1" : "0",
            root.cfg.recMic ? "1" : "0",
            String(root.cfg.recMicDevice),
            String(output)];
        pRecCmd.running = true;
    }
    function cancelRecPick() { root.recPick = false; }
    Timer { id: recPickTimer; interval: 8000; running: root.recPickActive
            onTriggered: root.cancelRecPick() }
    function stopRecord() {
        if (!root.recActive) return;
        pRecCmd.command = ["sh", "-c", root.recScript + " stop"];
        pRecCmd.running = true;
    }
    function pauseRecord() {
        if (!root.recActive) return;
        pRecCmd.command = ["sh", "-c", root.recScript + " pause"];
        pRecCmd.running = true;
    }
    function toggleRecord() { if (root.recActive) stopRecord(); else startRecord(); }

    property string voxState: ""
    readonly property bool voxActive: voxState.length > 0 && !expanded

    Timer {
        id: voxGuard
        interval: 8000
        running: root.voxState === "transcribing"
        onTriggered: root.voxState = ""
    }

    ListModel { id: micModel }
    readonly property var recMics: micModel
    Process {
        id: pRecMics
        command: ["sh", "-c", root.recScript + " mics"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 2) return;
                micModel.append({ mName: p[0], mDesc: p[1] });
            }
        }
    }
    function refreshMics() {
        micModel.clear();
        pRecMics.running = false;
        pRecMics.running = true;
    }

    Process { id: pMkRecDir }
    function openRecordDir() {
        var d = String(root.cfg.recDir);
        if (d.indexOf("~") === 0) d = Quickshell.env("HOME") + d.slice(1);
        pMkRecDir.command = ["sh", "-c", "mkdir -p \"$1\"", "_", d];
        pMkRecDir.running = true;
        root.filesDir = d;
        root.togglePage("files");
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property var btDevices: btAdapter ? btAdapter.devices : null
    readonly property var btConnectedDevice: {
        if (!btDevices) return null;
        var list = btDevices.values;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].connected) return list[i];
        return null;
    }
    readonly property string btConnectedName: {
        if (btConnectedDevice) return btConnectedDevice.name || "Device";
        return "";
    }
    readonly property string btConnectedType: {
        if (!btConnectedDevice) return "earbuds";
        var icon = String(btConnectedDevice.icon || "").toLowerCase();
        var name = String(btConnectedDevice.name || "").toLowerCase();
        if (icon === "input-mouse" || name.indexOf("mouse") >= 0) return "mouse";
        if (icon === "input-keyboard" || name.indexOf("keyboard") >= 0) return "keyboard";
        if (icon === "input-gaming" || name.indexOf("controller") >= 0 || name.indexOf("gamepad") >= 0 || name.indexOf("dualsense") >= 0 || name.indexOf("xbox") >= 0) return "gamepad";
        if (icon === "phone" || name.indexOf("phone") >= 0 || name.indexOf("iphone") >= 0 || name.indexOf("android") >= 0) return "phone";
        if (icon === "audio-speakers" || icon === "audio-speaker" || name.indexOf("speaker") >= 0) return "speaker";
        if (icon === "watch" || name.indexOf("watch") >= 0) return "watch";
        return "earbuds";
    }
    readonly property int btConnectedBattery: {
        if (btConnectedDevice && btConnectedDevice.batteryAvailable)
            return Math.round(btConnectedDevice.battery * 100);
        return -1;
    }

    property string btToastName: ""
    property string btToastType: "earbuds"
    property bool   btToastDisconnected: false
    property bool   btToastLowBatt: false
    property bool   btToastShown: false
    readonly property bool btToastActive: btToastShown && !expanded
    property string btPrevConnected: ""
    property bool   btLowBattNotified: false

    function btLowBattCheck() {
        if (!btConnectedDevice || root.btConnectedBattery < 0) {
            root.btLowBattNotified = false;
            return;
        }
        if (root.btConnectedBattery > 25) {
            root.btLowBattNotified = false;
            return;
        }
        if (root.btConnectedBattery <= 20 && !root.btLowBattNotified && root.btConnectedName.length > 0) {
            root.btLowBattNotified = true;
            root.showBtLowBattToast(root.btConnectedName, root.btConnectedType);
        }
    }

    onBtConnectedBatteryChanged: root.btLowBattCheck()

    onBtConnectedNameChanged: {
        var name = root.btConnectedName;
        if (name.length > 0 && name !== root.btPrevConnected) {
            root.btPrevConnected = name;
            root.btLowBattNotified = false;
            root.showBtToast(name, root.btConnectedType, false);
            root.btLowBattCheck();
        } else if (name.length === 0 && root.btPrevConnected.length > 0) {
            var prev = root.btPrevConnected;
            var prevType = root.btToastType;
            root.btPrevConnected = "";
            root.btLowBattNotified = false;
            root.showBtToast(prev, prevType, true);
        }
    }

    function showBtToast(name, type, isDisconnect) {
        root.btToastName = name;
        root.btToastType = type || "earbuds";
        root.btToastDisconnected = isDisconnect || false;
        root.btToastLowBatt = false;
        root.btToastShown = true;
        if (root.expanded && !root.holdOpen) root.collapse();
        btToastTimer.interval = 2500;
        btToastTimer.restart();
        root.playSound(isDisconnect ? "disconnect" : "connect");
    }

    function showBtLowBattToast(name, type) {
        root.btToastName = name;
        root.btToastType = type || "earbuds";
        root.btToastDisconnected = false;
        root.btToastLowBatt = true;
        root.btToastShown = true;
        if (root.expanded && !root.holdOpen) root.collapse();
        btToastTimer.interval = 3500;
        btToastTimer.restart();
        root.playSound("disconnect");
    }

    function dismissBtToast() {
        root.btToastShown = false;
        btToastTimer.stop();
    }
    Timer {
        id: btToastTimer
        interval: 2500
        onTriggered: root.dismissBtToast()
    }

    property bool acToastShown: false
    readonly property bool acToastActive:
        acToastShown && !expanded && root.isLaptop && !root.btToastActive
    property bool acPrev: root.acOnline
    property string acToastKind: "charge"

    onAcOnlineChanged: {
        if (root.acOnline && !root.acPrev && root.isLaptop) root.showAcToast();
        root.acPrev = root.acOnline;
    }
    function showAcToast(kind) {
        root.acToastKind = kind || "charge";
        root.acToastShown = true;
        if (root.expanded && !root.holdOpen) root.collapse();
        acToastTimer.restart();
        root.playSound(root.acToastKind === "lowbatt" ? "disconnect" : "charge");
    }
    function showBattLowToast() { root.showAcToast("lowbatt"); }
    function dismissAcToast() {
        root.acToastShown = false;
        acToastTimer.stop();
    }
    Timer {
        id: acToastTimer
        interval: root.acToastKind === "lowbatt" ? 3500 : 2300
        onTriggered: root.dismissAcToast()
    }

    Process { id: pBtUnblock; command: ["rfkill", "unblock", "bluetooth"] }
    function toggleBt() {
        if (!btAdapter) return;
        if (!btAdapter.enabled) {
            pBtUnblock.running = true;
            btPowerOn.restart();
        } else {
            btAdapter.enabled = false;
        }
    }
    Timer {
        id: btPowerOn
        interval: 250
        onTriggered: if (root.btAdapter) root.btAdapter.enabled = true;
    }
    function scanBt() {
        if (!btAdapter || !btAdapter.enabled) return;
        btAdapter.pairable = true;
        btAdapter.discovering = true;
        btScanStop.restart();
    }
    Timer { id: btScanStop; interval: 12000; onTriggered: if (root.btAdapter) root.btAdapter.discovering = false }

    IpcHandler {
        target: "pill"
        function voxListening(): void {
            root.voxState = "listening";
            root.playSound("voice_start");
        }
        function voxTranscribing(): void { root.voxState = "transcribing"; }
        function voxDone(): void {
            root.voxState = "";
            root.playSound("voice_done");
        }
        function voxUnavailable(): void {
            root.voxState = "";
            root.recError = root.tr("voxtype is not installed");
        }
        function launcher(): void { root.toggleLauncher(); }
        function overview(): void { root.toggleOverview(); }
        function launchpad(): void { root.toggleLaunchpad(); }
        function controls(): void { root.togglePage("main"); }
        function chat(): void { root.collapse(); Quickshell.execDetached(["loka-zapfast"]); }
        function chatService(name: string): void { root.collapse(); Quickshell.execDetached(["loka-zapfast"]); }
        function wifi(): void {
            if (root.expanded && root.page === "wifi") { root.collapse(); return; }
            root.togglePage("wifi");
        }
        function bluetooth(): void {
            if (root.expanded && root.page === "bt") { root.collapse(); return; }
            root.togglePage("bt");
        }
        function testBtToast(name: string, type: string): void {
            root.showBtToast(name || "AirPods Pro", type || "earbuds", false);
        }
        function testBtLowBatt(name: string, type: string): void {
            root.showBtLowBattToast(name || "AirPods Pro", type || "earbuds");
        }
        function testWifiToast(ssid: string, quality: string): void {
            root.showWifiToast(ssid || "Wi-Fi Network", parseInt(quality) || 85, false);
        }
        function settings(): void { root.settingsTab = 0; root.togglePage("settings"); }
        function settingsAt(tab: string): void {
            if (isNaN(parseInt(tab))) { root.openSettingsAt(tab); return; }
            root.settingsTab = parseInt(tab) || 0;
            if (root.page !== "settings" || !root.expanded) root.togglePage("settings");
        }
        function shortcuts(): void { root.toggleKeysWindow(); }
        function clipboard(): void { root.togglePage("clip"); }
        function powermenu(): void { root.togglePage("power"); }
        function weather(): void {
            if (root.weatherDetailsOpen) root.weatherDetailsOpen = false;
            else root.openWeatherDetails();
        }
        function weatherClose(): void { root.weatherDetailsOpen = false; }
        function smartClose(): string {
            if (!root.cfg.closePanaceaFirst) return "disabled";
            var anyOpen = root.expanded || root.launchpadOpen || root.overviewOpen || root.wallsOpen || root.keysWindowOpen || root.whatsNewOpen || root.weatherDetailsOpen;
            if (anyOpen) {
                if (root.weatherDetailsOpen) root.weatherDetailsOpen = false;
                else if (root.launchpadOpen) root.closeLaunchpad();
                else if (root.overviewOpen) root.closeOverview();
                else if (root.wallsOpen) root.closeWalls();
                else if (root.keysWindowOpen) root.closeKeysWindow();
                else if (root.whatsNewOpen) root.dismissWhatsNew();
                else if (root.expanded) root.collapse();
                return "closed_overlay";
            }
            return "none";
        }
        function cancelCapture(): void { root.cancelCaptureRequested(); }
        function freeze(path: string): void { root.freezeShot = "file://" + path; }
        function unfreeze(): void { root.freezeShot = ""; }
        function shotCopied(path: string): void { root.shotCopied(path); }
        function notifications(): void { root.togglePage("notif"); }
        function audio(): void { root.togglePage("audio"); }
        function calendar(): void { root.togglePage("cal"); }
        function theme(): void { root.toggleWalls(); }
        function worlds(): void { root.togglePage("worlds"); }
        function world(name: string): void { root.applyWorld(name); }
        function worldWalls(): void {
            if (worldWallsLoader.item && worldWallsLoader.item.open) worldWallsLoader.item.hide();
            else root.openWorldWalls("");
        }
        function worldNext(): void {
            var w = Themes.worlds(), i = 0;
            for (var k = 0; k < w.length; k++) if (w[k].id === root.cfg.themeId) i = k + 1;
            root.applyWorld(w[i % w.length].id);
        }
        function widgets(): void { root.cfg.featWidgets = !root.cfg.featWidgets; root.saveCfg(); }
        function record(): void { root.togglePage("record"); }
        function files(): void { root.togglePage("files"); }
        function filesAt(path: string): void { root.openFilesAt(path); }
        function passwords(): void { root.togglePage("vault"); }
        function agents(): void { root.openAgents(); }
        function media(path: string): void { root.openMedia(path); }
        function mediaCrop(): void { root.mediaCropToggle(); }
        function recordToggle(): void { root.toggleRecord(); }
        function dnd(): void { root.toggleDnd(); }
        function brightness(pct: string): void {
            var v = parseFloat(pct);
            root.showOsd("bright", v / 100.0, false);

            var l = root.brightList.slice();
            var hit = false;
            for (var i = 0; i < l.length; i++) {
                if (String(l[i].id).indexOf("bl:") === 0 || l.length === 1) {
                    l[i] = { id: l[i].id, name: l[i].name, pct: Math.round(v) };
                    hit = true;
                }
            }
            if (hit) root.brightList = l;
            else if (l.length === 0) root.brightRefresh(false);
        }
        function motion(on: string): void {
            root.cfg.reduceMotion = (on !== "on");
            root.saveCfg();
        }
        function close(): void { root.collapse(); }
    }

    screen: root.pickScreen

    readonly property var pickScreen: {
        var want = root.cfg.pillScreen;
        if (want && want !== "auto") {
            var all = Quickshell.screens;
            for (var i = 0; i < all.length; i++)
                if (all[i].name === want) return all[i];
        }
        if (!Compositor.isHyprland) {
            var nm = Compositor.focusedMonitor;
            return (nm && nm.screen) ? nm.screen : null;
        }
        var fm = Hyprland.focusedMonitor;
        return (fm && fm.screen) ? fm.screen : null;
    }

    anchors.top:    !root.pillAtBottom
    anchors.bottom: !root.pillAtTop
    anchors.left:   !root.pillAtRight
    anchors.right:  !root.pillAtLeft
    readonly property bool islandCompact: root.pillAtTop && !root.expanded && !root.holdOpen
        && capsule.height <= root.pillH + 4 && !root.toastActive && !root.osdActive
        && !root.btToastActive && !root.wifiToastActive && !root.acToastActive
        && !root.voxActive && !root.recPickActive && !root.pillDragging && !root.fileOverIsland
        && detachedPanel.opacity <= 0.005
    implicitHeight: root.islandCompact ? root.pillH + 80 : (root.screen ? root.screen.height : 1080)
    implicitWidth: root.screen ? root.screen.width : 1920
    color: "transparent"
    exclusiveZone: (root.cfg.pillOverlay || root.pillHidden || (root.fullscreenActive && !root.expanded))
                   ? 0 : pillH + gap

    visible: !root.fullscreenActive || root.expanded || root.osdActive

    Process {
        id: pCloseWin
        command: ["sh", "-c",
            "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then "
            + "niri msg action close-window >/dev/null 2>&1; "
            + "else out=$(hyprctl dispatch 'hl.dsp.window.close()' 2>&1); case \"$out\" in ok*) ;; *) hyprctl dispatch killactive ;; esac; fi"]
    }
    function closeActiveWindow(): void {
        pCloseWin.running = false;
        pCloseWin.running = true;
    }

    readonly property bool pillHidden: root.cfg.pillAutoHide
                                       && !root.expanded && !root.holdOpen
                                       && !root.osdActive && !root.pillDragging
                                       && !revealHover.hovered && !capsuleHover.hovered

    onPillHiddenChanged: {
        if (root.pillHidden) return;
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
    }

    Item {
        id: revealStrip
        visible: root.cfg.pillAutoHide
        anchors.top:    root.pillAtBottom ? undefined : parent.top
        anchors.bottom: root.pillAtBottom ? parent.bottom : undefined
        anchors.left:   root.pillAtRight  ? undefined : parent.left
        anchors.right:  root.pillAtRight  ? parent.right : undefined
        width:  root.pillSide ? 4 : parent.width
        height: root.pillSide ? parent.height : 4
        HoverHandler { id: revealHover }
    }

    Region {
        id: capsuleRegion
        item: capsule
        Region {
            item: root.cfg.pillAutoHide ? revealStrip : null
            intersection: Intersection.Combine
        }
        Region {
            item: (root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || detachedPanel.opacity > 0.005)) ? detachedPanel : null
            intersection: Intersection.Combine
        }
    }
    mask: root.holdOpen && !root.chatFilePickerOpen ? null : capsuleRegion
    focusable: root.holdOpen && !root.chatFilePickerOpen

    readonly property var activePanel: (root.cfg.pillKeepVisible && root.expanded && !root.settingsMode) ? detachedPanel : capsule

    Repeater {
        model: 4
        MouseArea {
            required property int index
            enabled: root.holdOpen
            visible: enabled
            z: 5
            x: index === 3 ? root.activePanel.x + root.activePanel.width : 0
            y: index === 1 ? root.activePanel.y + root.activePanel.height
             : index >= 2 ? root.activePanel.y : 0
            width:  index < 2 ? root.width
                  : index === 2 ? root.activePanel.x
                                : Math.max(0, root.width - root.activePanel.x - root.activePanel.width)
            height: index === 0 ? root.activePanel.y
                  : index === 1 ? Math.max(0, root.height - root.activePanel.y - root.activePanel.height)
                                : root.activePanel.height
            onClicked: root.collapse()
        }
    }

    Image {
        anchors.fill: parent
        z: -5
        source: (root.themeFading || opacity > 0.01) ? root.themeFadeWall : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.screen ? root.screen.width : 1920
        asynchronous: false
        cache: false
        visible: opacity > 0.01
        opacity: root.themeFading ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 700; easing.type: Easing.InOutCubic }
        }
    }

    Repeater {
        model: ["top", "bottom", "left", "right"]
        Rectangle {
            required property string modelData
            readonly property bool side: modelData === "left" || modelData === "right"
            readonly property bool lit: root.pillDragging && root.dragEdge === modelData

            width:  side ? 4 : parent.width
            height: side ? parent.height : 4
            x: modelData === "right" ? parent.width - width : 0
            y: modelData === "bottom" ? parent.height - height : 0
            z: 80
            radius: 2
            color: root.colOn
            opacity: lit ? 0.9 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    Rectangle {
        id: capsule
        scale: 1 - root.fileAbsorb * 0.05
        Behavior on scale { NumberAnimation { duration: root.noMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.fill: parent
            z: 499
            visible: (root.fileOverIsland || fileAbsorbAnimation.running) && !root.expanded
            color: root.colBg
            radius: Math.min(18, height / 2)
            Shape {
                id: dropOutline
                anchors.fill: parent; anchors.margins: 6
                opacity: 0.65; antialiasing: true
                readonly property real corner: Math.min(14, Math.max(0, height / 2 - 1))
                ShapePath {
                    strokeColor: root.colOn; strokeWidth: 1.2
                    strokeStyle: ShapePath.DashLine; dashPattern: [4, 4]
                    capStyle: ShapePath.RoundCap; fillColor: "transparent"
                    startX: dropOutline.corner; startY: 0.6
                    PathLine { x: dropOutline.width - dropOutline.corner; y: 0.6 }
                    PathQuad { x: dropOutline.width - 0.6; y: dropOutline.corner; controlX: dropOutline.width - 0.6; controlY: 0.6 }
                    PathLine { x: dropOutline.width - 0.6; y: dropOutline.height - dropOutline.corner }
                    PathQuad { x: dropOutline.width - dropOutline.corner; y: dropOutline.height - 0.6; controlX: dropOutline.width - 0.6; controlY: dropOutline.height - 0.6 }
                    PathLine { x: dropOutline.corner; y: dropOutline.height - 0.6 }
                    PathQuad { x: 0.6; y: dropOutline.height - dropOutline.corner; controlX: 0.6; controlY: dropOutline.height - 0.6 }
                    PathLine { x: 0.6; y: dropOutline.corner }
                    PathQuad { x: dropOutline.corner; y: 0.6; controlX: 0.6; controlY: 0.6 }
                }
            }
            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 12
                    color: Qt.rgba(root.colOn.r, root.colOn.g, root.colOn.b, 0.15)
                    Text {
                        anchors.centerIn: parent
                        text: "󰈙"
                        color: root.colOn
                        font { family: root.fontFam; pixelSize: 17 }
                        scale: Math.max(0.25, 1 - root.fileAbsorb * 0.75)
                        opacity: Math.max(0.3, 1 - root.fileAbsorb * 0.7)
                    }
                }
                ColumnLayout {
                    spacing: 1
                    Text {
                        text: root.tr("Drop file here")
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: 12; bold: true }
                    }
                    Text {
                        text: root.tr("Quick actions")
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: 10 }
                    }
                }
            }
        }
        DropArea {
            anchors.fill: parent
            z: 500
            visible: !root.expanded
            keys: ["text/uri-list"]
            onEntered: drag => {
                drag.accepted = drag.hasUrls;
                root.fileOverIsland = drag.hasUrls;
                if (drag.hasUrls) { expandTimer.stop(); collapseTimer.stop(); }
            }
            onExited: root.fileOverIsland = false
            onDropped: drop => { root.fileOverIsland = false; if (drop.hasUrls) { drop.accept(Qt.CopyAction); root.openDroppedFile(drop.urls); } }
        }

        anchors.top:    root.pillAtTop    ? parent.top    : undefined
        anchors.bottom: root.pillAtBottom ? parent.bottom : undefined
        anchors.left:   root.pillAtLeft   ? parent.left   : undefined
        anchors.right:  root.pillAtRight  ? parent.right  : undefined
        anchors.horizontalCenter: root.pillSide ? undefined : parent.horizontalCenter
        anchors.verticalCenter:   root.pillSide ? parent.verticalCenter : undefined

        readonly property real freeGap: root.cfg.notchMode ? 0 : root.cfg.islandGap
        readonly property real edgeMargin: root.settingsMode && !root.pillSide
                                           ? Math.max(24, (root.height - targetH) / 2)
                                           : root.pillHidden ? -(targetH + 4) : freeGap
        readonly property real sideMargin: root.settingsMode && root.pillSide
                                           ? Math.max(24, (root.width - width) / 2)
                                           : root.pillHidden ? -(width + 4) : freeGap
        anchors.topMargin:    root.pillAtTop    ? edgeMargin : 0
        anchors.bottomMargin: root.pillAtBottom ? edgeMargin : 0
        anchors.leftMargin:   root.pillAtLeft   ? sideMargin : 0
        anchors.rightMargin:  root.pillAtRight  ? sideMargin : 0
        Behavior on anchors.leftMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.rightMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.topMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }

        property real flyT: 0
        property real flySX: 0
        property real flySY: 0
        property real flySS: 10
        property real flySG: 0.1
        function startFlight(src) {
            var p = src.mapToItem(capsule, 0, 0);
            capsule.flySX = p.x; capsule.flySY = p.y; capsule.flySS = src.size; capsule.flySG = src.gapRatio;
            flyClock.x = p.x; flyClock.y = p.y; flyClock.size = src.size; flyClock.gapRatio = src.gapRatio;
            flyAnim.stop();
            capsule.flyT = 0;
            root.clockFlying = true;
            flyWait.tries = 0;
            flyWait.restart();
        }
        onFlyTChanged: {
            var t = root.ccClockItem;
            if (!root.clockFlying || !t) return;
            var q = t.mapToItem(capsule, 0, 0);
            var k = capsule.flyT;
            flyClock.x = capsule.flySX + (q.x - capsule.flySX) * k;
            flyClock.y = capsule.flySY + (q.y - capsule.flySY) * k;
            flyClock.size = capsule.flySS + (t.size - capsule.flySS) * k;
            flyClock.gapRatio = capsule.flySG + (t.gapRatio - capsule.flySG) * k;
        }
        Timer {
            id: flyWait
            property int tries: 0
            interval: 16; repeat: true
            onTriggered: {
                tries++;
                var t = root.ccClockItem;
                if (t && t.visible && t.width > 0) { stop(); flyAnim.restart(); }
                else if (tries > 40) { stop(); root.clockFlying = false; }
            }
        }
        NumberAnimation {
            id: flyAnim
            target: capsule; property: "flyT"; from: 0; to: 1
            duration: 460; easing.type: Easing.OutCubic
            onFinished: root.clockFlying = false
        }
        DotText {
            id: flyClock
            z: 500
            visible: root.clockFlying
            value: root.timeText
            color: root.colFg
        }

        readonly property int collapsedMin: root.minimalPill ? 0 : Math.max(root.cfg.collapsedW, 420)

        function evenUp(v) { return Math.round(v / 2) * 2; }

        readonly property real idleLen: root.fileOverIsland || fileAbsorbAnimation.running
                    ? capsule.evenUp(Math.max(300, capsule.collapsedMin))
                : root.voxActive
                    ? capsule.evenUp(Math.max(voxCapsule.implicitWidth + 40, 240))
                : root.recPickActive
                    ? capsule.evenUp(Math.max(recPickCapsule.implicitWidth + 28, 240))
                : root.btToastActive
                    ? capsule.evenUp(Math.max(btCapsule.implicitWidth + 48, 240))
                : root.wifiToastActive
                    ? capsule.evenUp(Math.max(wifiCapsule.implicitWidth + 48, 240))
                : root.acToastActive
                    ? capsule.evenUp(Math.max(acCapsule.implicitWidth + 48, 240))
                : root.toastActive ? 440
                : root.osdActive ? capsule.evenUp(osdCapsule.implicitWidth + 32)
                : root.pillSide  ? capsule.evenUp(Math.max(vertCapsule.implicitHeight + 30,
                                                           capsule.collapsedMin))
                : root.peekOpen ? 420
                : capsule.evenUp(Math.max(nothingCapsule.implicitWidth + 28,
                                          capsule.collapsedMin))
        readonly property real idleThick: (root.fileOverIsland || fileAbsorbAnimation.running) ? 58
                : (root.btToastActive || root.wifiToastActive || root.acToastActive
                    || root.recPickActive || root.voxActive)
                ? root.pillH
                : root.toastActive
                ? toastCapsule.implicitHeight + 24
                : root.peekOpen ? 72 : root.pillH

        width: root.settingsMode ? root.settingsW
             : (root.expanded && !root.cfg.pillKeepVisible) ? root.panelW
             : root.pillSide     ? idleThick
                                 : idleLen
        property real contentH: 220

        Timer {
            id: contentSettle
            interval: 24
            onTriggered: capsule.applyContentH()
        }
        function refreshContentH() { contentSettle.restart(); }
        function applyContentH() {
            var it = contentLoader.item;
            if (!it || it.implicitHeight <= 40) return;
            var target = it.implicitHeight + ((root.page === "main" || root.page === "chat" || root.page === "vpn") && !root.settingsMode ? 75 : 30);
            if (Math.abs(target - capsule.contentH) < 8) return;
            capsule.contentH = target;
        }
        Connections {
            target: contentLoader
            function onItemChanged() { capsule.refreshContentH(); }
        }
        Connections {
            target: contentLoader.item
            ignoreUnknownSignals: true
            function onImplicitHeightChanged() { capsule.refreshContentH(); }
        }

        readonly property real targetH: root.settingsMode ? Math.min(contentH, root.height - 48)
                : (root.expanded && !root.cfg.pillKeepVisible) ? Math.min(contentH, root.cfg.expandedH)
                : root.pillSide ? idleLen
                                : idleThick
        height: Math.min(targetH, root.height - root.gap * 2)

        transform: Translate {
            x: root.dragDX
            y: root.dragDY
            Behavior on x {
                enabled: !root.pillDragging
                NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !root.pillDragging
                NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
            }
        }

        onXChanged:      root.pillRectX = capsule.x
        onYChanged:      root.pillRectY = capsule.y
        onWidthChanged:  root.pillRectW = capsule.width
        onHeightChanged: root.pillRectH = capsule.height
        Component.onCompleted: {
            root.pillRectX = capsule.x;      root.pillRectY = capsule.y;
            root.pillRectW = capsule.width;  root.pillRectH = capsule.height;
        }

        opacity: root.wallsOpen ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: root.animFast } }

        color: root.colBg
        readonly property real edgeR: (root.settingsMode || !root.cfg.notchMode)
                                      ? (root.cfg.islandRadius > 0 ? root.cfg.islandRadius : 26)
                                      : 0
        readonly property real freeR: (root.settingsMode || (root.expanded && !root.cfg.pillKeepVisible))
                ? (root.cfg.islandRadius > 0 && !root.cfg.notchMode ? root.cfg.islandRadius : 26)
                : (root.cfg.islandRadius > 0 && !root.cfg.notchMode
                   ? root.cfg.islandRadius : root.pillH / 2)
        topLeftRadius:     root.pillAtTop || root.pillAtLeft  ? edgeR : freeR
        topRightRadius:    root.pillAtTop || root.pillAtRight ? edgeR : freeR
        bottomLeftRadius:  root.pillAtBottom || root.pillAtLeft  ? edgeR : freeR
        bottomRightRadius: root.pillAtBottom || root.pillAtRight ? edgeR : freeR
        Behavior on topLeftRadius  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }

        border.width: 0

        Behavior on width {
            NumberAnimation {
                duration: root.animMs
                easing.type: root.animBounce > 0 ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: root.easeOvershoot
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.morphing ? root.animMs : root.animQuick
                easing.type: root.animBounce > 0 ? Easing.OutBack
                           : root.morphing ? Easing.InOutCubic : Easing.OutCubic
                easing.overshoot: root.easeOvershoot
            }
        }
        Behavior on bottomLeftRadius  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }

        clip: true

        HoverHandler {
            id: capsuleHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            property point armPos: Qt.point(-9999, -9999)
            function markArmPoint() {
                capsuleHover.armPos = capsuleHover.hovered
                        ? capsuleHover.point.scenePosition : Qt.point(-9999, -9999);
            }
            onPointChanged: {
                if (root.hoverExpandArmed || !capsuleHover.hovered) return;
                var p = capsuleHover.point.scenePosition;
                if (Math.abs(p.x - capsuleHover.armPos.x)
                    + Math.abs(p.y - capsuleHover.armPos.y) < 12) return;
                root.hoverExpandArmed = true;
                expandTimer.restart();
            }

            onHoveredChanged: {
                if (hovered && !root.hoverExpandArmed)
                    capsuleHover.armPos = capsuleHover.point.scenePosition;
                if (hovered) {
                    collapseTimer.stop();
                    expandTimer.restart();
                    rearmTimer.stop();
                } else {
                    expandTimer.stop();
                    root.peekOpen = false;
                    collapseTimer.restart();
                    rearmTimer.restart();
                }
            }
        }
        function openPanel() {
            if (root.peekOpen && root.peekClockItem) capsule.startFlight(root.peekClockItem);
            root.peekOpen = false;
            if (!root.expanded) {
                pageResetTimer.stop();
                root.page = "main";
            }
            root.expanded = true;
        }

        Timer {
            id: expandTimer; interval: 0
            onTriggered: {
                if (!capsuleHover.hovered || root.launcherOpen || root.fileOverIsland || fileDrag.Drag.active) return;
                if (!root.hoverExpandArmed) return;
                if (root.toastActive || root.btToastActive || root.wifiToastActive || root.acToastActive || root.recPickActive || root.voxActive) return;
                if (root.cfg.pillAutoHide) return;
                if (root.expanded) return;
                root.peekOpen = true;
            }
        }
        Timer {
            id: rearmTimer
            interval: 450
            onTriggered: root.hoverExpandArmed = true
        }
        Timer {
            id: collapseTimer; interval: 180
            onTriggered: {
                if (capsuleHover.hovered || (detachedHover.hovered && root.cfg.pillKeepVisible) || root.holdOpen) return;
                root.collapse();
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            enabled: !root.expanded && !root.toastActive && !root.pillDragging
                     && !root.osdActive && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            cursorShape: Qt.PointingHandCursor
            onClicked: capsule.openPanel()
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: root.cfg.pillKeepVisible && root.expanded && !root.settingsMode
                     && !root.toastActive && !root.pillDragging
            cursorShape: Qt.PointingHandCursor
            onClicked: root.collapse()
        }

        MouseArea {
            anchors.fill: parent
            z: 100
            enabled: root.toastActive
            visible: enabled
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.notifCurrent) root.activateNotification(root.notifCurrent)
        }

        RowLayout {
            id: toastCapsule
            z: 110
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            anchors.topMargin: root.approvalToast ? 16 : 12
            spacing: 12
            visible: root.toastActive && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignTop
                radius: 10
                color: root.notifUrgent ? Qt.rgba(1, 0.27, 0.27, 0.18)
                                        : Pal.a(0.08)

                Image {
                    id: toastIcon
                    anchors.fill: parent
                    anchors.margins: 5
                    source: root.notifImage
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !toastIcon.visible
                    text: String.fromCodePoint(root.notifUrgent ? 0xF0026 : 0xF009A)
                    color: root.notifUrgent ? root.colCrit : root.colFg
                    font { family: root.fontFam; pixelSize: root.iconSize - 1 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.approvalToast ? 7 : 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: root.notifSummary
                        color: root.colFg
                        elide: Text.ElideRight
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }
                    Text {
                        text: root.notifApp
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.notifBody.length > 0 && (root.cfg.notifPreview || root.approvalToast)
                    text: root.notifBody
                    color: root.colMuted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    font { family: root.fontFam; pixelSize: root.fontSize - 3 }
                }

            }

            Column {
                visible: root.approvalToast
                Layout.alignment: Qt.AlignVCenter
                spacing: 6
                Repeater {
                    model: [{action:"panacea-deny", label:"×"}, {action:"panacea-allow", label:"✓"}]
                    delegate: Rectangle {
                        required property var modelData
                        width: 30; height: 30; radius: 15
                        color: modelData.action === "panacea-allow" ? "#305f46" : "#643f45"
                        Text { anchors.centerIn: parent; text: modelData.label; color: modelData.action === "panacea-allow" ? "#9be0b1" : "#f0b3b6"; font { pixelSize: 17; bold: true } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.replyAgentApproval(modelData.action) }
                    }
                }
            }

            Text {
                visible: !root.approvalToast
                Layout.alignment: Qt.AlignTop
                text: "×"
                color: closeMa.containsMouse ? root.colFg : root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize + 2 }
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.approvalToast && root.notifCurrent) root.notifCurrent.dismiss(); root.dismissToast(); }
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: 3; radius: 2; z: 120
            visible: root.toastActive && root.approvalToast
            color: Pal.a(0.12)
            Rectangle { width: parent.width * Math.max(0, Math.min(1, root.approvalToastRemaining / 30000)); height: parent.height; radius: 2; color: root.colFg }
        }

        RowLayout {
            id: btCapsule
            z: 110
            anchors.centerIn: parent
            spacing: 11
            visible: root.btToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 4

                Text {
                    anchors.centerIn: parent
                    text: root.btToastDisconnected ? String.fromCodePoint(0xF00B2)
                        : root.btToastType === "earbuds" ? String.fromCodePoint(0xF184F)
                        : root.btToastType === "mouse" ? String.fromCodePoint(0xF098B)
                        : root.btToastType === "keyboard" ? String.fromCodePoint(0xF030C)
                        : root.btToastType === "gamepad" ? String.fromCodePoint(0xF02B4)
                        : root.btToastType === "phone" ? String.fromCodePoint(0xF011E)
                        : root.btToastType === "speaker" ? String.fromCodePoint(0xF04C3)
                        : root.btToastType === "watch" ? String.fromCodePoint(0xF0584)
                        : String.fromCodePoint(0xF00AF)
                    color: (root.btToastDisconnected || root.btToastLowBatt) ? root.colCrit : root.colFg
                    font { family: root.fontFam; pixelSize: root.btToastType === "earbuds" ? 24 : 21 }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                transform: Translate { y: -2 }

                Text {
                    text: root.btToastLowBatt ? root.tr("Low battery")
                        : root.btToastDisconnected ? root.tr("Disconnected")
                        : root.tr("Connected")
                    color: (root.btToastDisconnected || root.btToastLowBatt) ? root.colCrit : root.colMuted
                    transform: Translate { y: 2 }
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
                Text {
                    Layout.maximumWidth: 220
                    text: root.btToastName
                    color: root.colFg
                    elide: Text.ElideRight
                    font { family: root.fontFam; pixelSize: root.fontSize + 1; bold: true }
                }
            }

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 48

                Canvas {
                    id: btRing
                    anchors.fill: parent
                    visible: !root.btToastDisconnected && root.btConnectedBattery >= 0

                    readonly property real level:
                        root.btConnectedBattery >= 0 ? root.btConnectedBattery / 100 : 0
                    property real fill: 0
                    readonly property real lineW: 3.5

                    onFillChanged: requestPaint()
                    onLevelChanged: {
                        if (!root.btToastActive) return;
                        btRingAnim.stop();
                        btRingAnim.from = btRing.fill;
                        btRingAnim.to = btRing.level;
                        btRingAnim.start();
                    }

                    NumberAnimation {
                        id: btRingAnim
                        target: btRing; property: "fill"
                        duration: 900; easing.type: Easing.OutCubic
                    }
                    function play() {
                        btRingAnim.stop();
                        btRing.fill = 0;
                        btRingAnim.from = 0;
                        btRingAnim.to = btRing.level;
                        btRingAnim.start();
                    }
                    Connections {
                        target: root
                        function onBtToastActiveChanged() {
                            if (root.btToastActive) btRing.play();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (width <= 0 || height <= 0) return;
                        var c = (root.btConnectedBattery >= 0 && root.btConnectedBattery <= 20)
                                ? root.colCrit
                                : root.colOn;
                        var r = (Math.min(width, height) - lineW) / 2;
                        var cx = width / 2, cy = height / 2;

                        ctx.lineWidth = lineW;
                        ctx.lineCap = "round";

                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.22);
                        ctx.stroke();

                        if (fill > 0) {
                            var start = -Math.PI / 2;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, start, start + 2 * Math.PI * fill);
                            ctx.strokeStyle = c;
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(root.btConnectedBattery)
                        color: root.btConnectedBattery <= 20 ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 6; bold: true }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !root.btToastDisconnected && root.btConnectedBattery < 0
                    radius: 14
                    color: Pal.a(0.10)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF00AF)
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.btToastDisconnected
                    radius: 14
                    color: Qt.rgba(1, 0, 0, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF00B2)
                        color: root.colCrit
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }
            }
        }

        RowLayout {
            id: wifiCapsule
            z: 110
            anchors.centerIn: parent
            spacing: 11
            visible: root.wifiToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 4

                Text {
                    anchors.centerIn: parent
                    text: root.wifiToastDisconnected ? "󰤮"
                        : root.wifiToastQuality > 66 ? "󰤨"
                        : root.wifiToastQuality > 33 ? "󰤥" : "󰤟"
                    color: root.wifiToastDisconnected ? root.colCrit : root.colFg
                    font { family: root.fontFam; pixelSize: 22 }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                transform: Translate { y: -2 }

                Text {
                    text: root.wifiToastDisconnected ? root.tr("Disconnected") : root.tr("Connected")
                    color: root.wifiToastDisconnected ? root.colCrit : root.colMuted
                    transform: Translate { y: 2 }
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
                Text {
                    Layout.maximumWidth: 220
                    text: root.wifiToastSsid
                    color: root.colFg
                    elide: Text.ElideRight
                    font { family: root.fontFam; pixelSize: root.fontSize + 1; bold: true }
                }
            }

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 48

                Canvas {
                    id: wifiRing
                    anchors.fill: parent
                    visible: !root.wifiToastDisconnected && root.wifiToastQuality >= 0

                    readonly property real level:
                        root.wifiToastQuality >= 0 ? root.wifiToastQuality / 100 : 0
                    property real fill: 0
                    readonly property real lineW: 3.5

                    onFillChanged: requestPaint()
                    onLevelChanged: {
                        if (!root.wifiToastActive) return;
                        wifiRingAnim.stop();
                        wifiRingAnim.from = wifiRing.fill;
                        wifiRingAnim.to = wifiRing.level;
                        wifiRingAnim.start();
                    }

                    NumberAnimation {
                        id: wifiRingAnim
                        target: wifiRing; property: "fill"
                        duration: 900; easing.type: Easing.OutCubic
                    }
                    function play() {
                        wifiRingAnim.stop();
                        wifiRing.fill = 0;
                        wifiRingAnim.from = 0;
                        wifiRingAnim.to = wifiRing.level;
                        wifiRingAnim.start();
                    }
                    Connections {
                        target: root
                        function onWifiToastActiveChanged() {
                            if (root.wifiToastActive) wifiRing.play();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (width <= 0 || height <= 0) return;
                        var c = (root.wifiToastQuality >= 0 && root.wifiToastQuality <= 25)
                                ? root.colCrit
                                : root.colOn;
                        var r = (Math.min(width, height) - lineW) / 2;
                        var cx = width / 2, cy = height / 2;

                        ctx.lineWidth = lineW;
                        ctx.lineCap = "round";

                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.22);
                        ctx.stroke();

                        if (fill > 0) {
                            var start = -Math.PI / 2;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, start, start + 2 * Math.PI * fill);
                            ctx.strokeStyle = c;
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(root.wifiToastQuality)
                        color: root.wifiToastQuality <= 25 ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 6; bold: true }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.wifiToastDisconnected
                    radius: 14
                    color: Qt.rgba(1, 0, 0, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: "󰤮"
                        color: root.colCrit
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }
            }
        }

        Canvas {
            id: acWave
            anchors.fill: parent
            z: 1
            visible: root.acToastActive
            property color tint: root.acToastKind === "lowbatt" ? root.colCrit : root.colOk
            property real level: root.batteryPct / 100
            property real phase: 0
            onPhaseChanged: requestPaint()
            onLevelChanged: requestPaint()
            onTintChanged: requestPaint()

            Timer {
                interval: 45
                running: root.acToastActive && acWave.visible
                repeat: true
                onTriggered: acWave.phase += 0.16
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                if (width <= 0 || height <= 0) return;

                var mr = Math.min(width, height) / 2;
                var tl = Math.min(capsule.topLeftRadius, mr);
                var tr = Math.min(capsule.topRightRadius, mr);
                var br = Math.min(capsule.bottomRightRadius, mr);
                var bl = Math.min(capsule.bottomLeftRadius, mr);
                ctx.beginPath();
                ctx.moveTo(tl, 0);
                ctx.arcTo(width, 0, width, height, tr);
                ctx.arcTo(width, height, 0, height, br);
                ctx.arcTo(0, height, 0, 0, bl);
                ctx.arcTo(0, 0, width, 0, tl);
                ctx.closePath();
                ctx.clip();

                var base = height * (1 - Math.max(0.12, Math.min(0.92, level)));
                var amp = 3.2;

                for (var w = 0; w < 2; w++) {
                    var off = w === 0 ? 0 : Math.PI * 0.7;
                    var k = w === 0 ? 0.055 : 0.041;
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    for (var x = 0; x <= width; x += 3) {
                        var y = base + amp * Math.sin(k * x + phase + off)
                                     + amp * 0.5 * Math.sin(k * 1.9 * x - phase * 0.7);
                        if (x === 0) ctx.lineTo(0, y); else ctx.lineTo(x, y);
                    }
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, w === 0 ? 0.16 : 0.11);
                    ctx.fill();
                }
            }
        }

        RowLayout {
            id: acCapsule
            z: 110
            anchors.centerIn: parent
            spacing: 8
            visible: root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.acToastKind === "lowbatt" ? String.fromCodePoint(0xF008E)
                                                      : String.fromCodePoint(0xF0241)
                color: root.acToastKind === "lowbatt" ? root.colCrit : root.colOk
                font { family: root.fontFam; pixelSize: root.iconSize + 3 }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.acToastKind === "lowbatt" ? root.tr("Low battery")
                                                      : root.tr("Charging")
                color: root.acToastKind === "lowbatt" ? root.colCrit : root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.batteryPct + "%"
                color: root.acToastKind === "lowbatt" ? root.colCrit : root.colOk
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
        }

        RowLayout {
            id: recPickCapsule
            z: 130
            anchors.centerIn: parent
            spacing: 9
            visible: root.recPickActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF044A)
                color: root.colCrit
                font { family: root.fontFam; pixelSize: root.iconSize + 2 }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.tr("Record screen")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
            Repeater {
                model: root.recPickMons
                delegate: Rectangle {
                    required property var modelData
                    Layout.alignment: Qt.AlignVCenter
                    radius: 9
                    implicitWidth: chipTxt.implicitWidth + 20
                    implicitHeight: 26
                    color: chipMa.containsMouse ? root.colOn : Pal.a(0.10)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: chipTxt
                        anchors.centerIn: parent
                        text: modelData.name
                        color: chipMa.containsMouse ? "#ffffff" : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startRecordOn(modelData.name)
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "×"
                color: pickCloseMa.containsMouse ? root.colFg : root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize + 2 }
                MouseArea {
                    id: pickCloseMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelRecPick()
                }
            }
        }

        RowLayout {
            id: voxCapsule
            z: 120
            anchors.centerIn: parent
            spacing: 10
            visible: root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF036C)
                color: root.voxState === "listening" ? root.colCrit : root.colFg
                font { family: root.fontFam; pixelSize: root.iconSize + 3 }

                SequentialAnimation on opacity {
                    running: root.voxState === "transcribing"
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.35; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                }
                onVisibleChanged: if (!visible) opacity = 1
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.voxState === "transcribing" ? root.tr("Transcribing…")
                                                       : root.tr("Listening…")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }

            MicWaveBars {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 18
                visible: root.voxState === "listening"
                active: root.voxState === "listening" && root.voxActive
                barColor: root.colCrit
                barCount: 9
                gap: 2.5
            }
        }

        RowLayout {
            id: osdCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 12
            visible: root.osdActive && !root.toastActive && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                text: root.osdIcon
                color: root.osdMuted ? root.colMuted : root.colFg
                Layout.preferredWidth: mOsdIcon.width + 4
                horizontalAlignment: Text.AlignHCenter
                font { family: root.fontFam; pixelSize: root.iconSize }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 5
                Layout.alignment: Qt.AlignVCenter
                radius: 3
                color: Pal.a(0.16)

                Rectangle {
                    width: parent.width * (root.osdMuted ? 0 : root.osdValue)
                    height: parent.height
                    radius: 3
                    color: root.osdKind === "bright" ? root.colWarn : root.colOn
                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }

            Text {
                Layout.preferredWidth: mBatt.width
                horizontalAlignment: Text.AlignRight
                text: root.osdMuted ? "—" : Math.round(root.osdValue * 100) + "%"
                color: root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            }
        }

        TextMetrics {
            id: mClock
            font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            text: (root.cfg.clock12 ? "12:00" : "00:00")
                  + (root.cfg.clockSeconds ? ":00" : "")
                  + (root.cfg.clock12 ? " PM" : "")
        }
        TextMetrics {
            id: mBatt
            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            text: "100%"
        }
        TextMetrics {
            id: mBattIcon
            font { family: root.fontFam; pixelSize: root.iconSize }
            text: String.fromCodePoint(0xF0079)
        }
        TextMetrics {
            id: mOsdIcon
            font { family: root.fontFam; pixelSize: root.iconSize }
            text: String.fromCodePoint(0xF057E)
        }
        TextMetrics {
            id: mWs
            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            text: "10"
        }

        Item {
            id: peekCapsule
            anchors.fill: parent
            anchors.leftMargin: 26
            anchors.rightMargin: 22
            visible: opacity > 0
            opacity: root.peekOpen && !root.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }
            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                DotText {
                    id: peekClock
                    value: root.timeText; size: root.dotHClock * 1.7; gapRatio: 0.1; color: root.colFg
                    opacity: root.clockFlying ? 0 : 1
                    Component.onCompleted: root.peekClockItem = peekClock
                }
                Text { text: root.dateLong; color: root.colMuted; font { family: root.fontFam; pixelSize: root.fontSize - 3 } }
            }
            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(200, parent.width - 160)
                spacing: 3
                visible: root.player !== null && root.player !== undefined && String(root.player.trackTitle || "") !== ""
                Text { width: parent.width; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: root.player ? String(root.player.trackTitle || "") : ""; color: root.colFg; font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true } }
                Text { width: parent.width; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: root.player ? String(root.player.trackArtist || "") : ""; color: root.colMuted; font { family: root.fontFam; pixelSize: root.fontSize - 4 } }
                Rectangle {
                    anchors.right: parent.right
                    width: 120; height: 3; radius: 1.5; color: Pal.a(0.15)
                    Rectangle { width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0; height: parent.height; radius: 1.5; color: root.colFg }
                }
            }
        }

        Item {
            id: nothingCapsule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: root.pillH
            visible: !root.peekOpen && (!root.expanded || (root.cfg.pillKeepVisible && !root.settingsMode)) && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
                     && !root.osdActive && !root.toastActive
            opacity: root.pillSide ? 0 : (visible ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            readonly property real armGap: root.minimalPill ? 0 : 22

            readonly property int wsSlots: 5
            readonly property real wsReserve:
                nothingCapsule.wsSlots * 6
                + (nothingCapsule.wsSlots - 1) * nLeft.spacing
                + (17 - 6)
            readonly property real arm:
                Math.max(nLeft.implicitWidth, nRight.implicitWidth)
            implicitWidth: root.minimalPill ? nClock.implicitWidth + 20 : nClock.implicitWidth + 2 * (nothingCapsule.arm + nothingCapsule.armGap)

            RowLayout {
                id: nLeft
                visible: !root.minimalPill
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    Layout.alignment: Qt.AlignVCenter
                    radius: 4
                    visible: root.recActive
                    color: root.recPaused ? root.colWarn : root.colCrit
                    SequentialAnimation on opacity {
                        running: root.recActive && !root.recPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                    }
                    onVisibleChanged: if (!visible) opacity = 1
                }

                Item {
                    Layout.preferredWidth: Math.max(wsRow.implicitWidth,
                                                    nothingCapsule.wsReserve)
                    Layout.preferredHeight: 6
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        id: wsRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: nLeft.spacing

                Repeater {
                    model: root.wsList

                    Rectangle {
                        required property var modelData
                        readonly property bool here: modelData === root.wsId
                        property real len: here ? 17 : 6

                        property bool settled: false
                        Component.onCompleted: settled = true

                        Layout.preferredWidth: len
                        Layout.preferredHeight: 6
                        Layout.alignment: Qt.AlignVCenter
                        radius: 3
                        color: root.colFg
                        opacity: here ? 1 : (wsMa.containsMouse ? 0.6 : 0.3)

                        Behavior on len {
                            enabled: settled
                            NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            enabled: settled
                            NumberAnimation { duration: root.animFast }
                        }

                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.gotoWorkspace(modelData)
                        }
                    }
                }
                    }
                }

                Item  {
                    id: weatheritem

                    implicitHeight: weatherrow.implicitHeight
                    implicitWidth: weatherrow.implicitWidth

                    RowLayout {
                       id: weatherrow

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 6

                        spacing: 5
                        visible: root.weatherReady && root.cfg.weatherOnIsland

                        DotIcon {
                            Layout.alignment: Qt.AlignVCenter
                            code: root.weatherIcon
                            size: root.dotHClock
                            color: islWthMa2.containsMouse ? root.colOn : root.colFg
                        }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: root.weatherTemp + "°"
                            color: islWthMa2.containsMouse ? root.colOn : root.colFg
                            font { family: root.fontFam; pixelSize: root.fontSize }
                        }
                    }
                    
                    MouseArea {
                        id: islWthMa2
                        anchors.fill: weatheritem
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openWeatherDetails()
                    }
                }
            }

            DotText {
                id: nClock
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 0
                Behavior on anchors.horizontalCenterOffset { enabled: !root.expanded && capsule.height <= root.pillH + 2; NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
                value: root.timeText
                size: root.dotHClock
                gapRatio: 0.1
                color: root.colFg
            }

            RowLayout {
                id: nRight
                visible: !root.minimalPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadGpu >= 0)
                    text: (root.loadCpu >= 0 ? "CPU " + root.loadCpu + "%" + (root.loadTempCpu >= 0 ? " " + root.loadTempCpu + "°" : "") : "")
                        + (root.loadGpu >= 0 ? "  GPU " + root.loadGpu + "%" + (root.loadTempGpu >= 0 ? " " + root.loadTempGpu + "°" : "") : "")
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                }

                LanGlyph {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.iconSize - 6
                    Layout.preferredHeight: root.iconSize - 6
                    visible: root.wiredOn
                    color: root.colFg
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: !root.wiredOn
                    text: root.wifiOn ? (root.wifiQuality > 66 ? "󰤨"
                                       : root.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                    color: root.wifiOn ? root.colFg : root.colMuted
                    font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                }

                FlipText {
                    Layout.alignment: Qt.AlignVCenter
                    value: root.kbLayout
                    textColor: root.colFg
                    fontFam: root.fontFam
                    pixelSize: root.fontSize - 4
                    bold: true
                }

                RowLayout {
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: !root.sinkAudio ? String.fromCodePoint(0xF075F)
                            : root.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                            : root.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                            : root.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                                           : String.fromCodePoint(0xF057E)
                        color: (root.sinkAudio && root.sinkAudio.muted)
                               ? root.colMuted : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                    }

                    DotText {
                        Layout.alignment: Qt.AlignVCenter
                        value: root.sinkAudio
                               ? String(Math.round(root.sinkAudio.volume * 100)) : "0"
                        size: root.dotHSmall
                        color: (root.sinkAudio && root.sinkAudio.muted)
                               ? root.colMuted : root.colFg
                    }
                }

                RowLayout {
                    spacing: 6
                    visible: root.batteryPresent

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.batteryIcon
                        color: root.batteryPct <= 15 && !root.acOnline
                               ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                    }

                    DotText {
                        Layout.alignment: Qt.AlignVCenter
                        value: String(root.batteryPct)
                        size: root.dotHSmall
                        color: root.batteryPct <= 15 && !root.acOnline
                               ? root.colCrit : root.colFg
                    }
                }
            }
        }

            component VertText: Column {
                id: vt
                property string value: ""
                property color textColor: root.colFg
                property real size: root.fontSize
                property bool bold: false
                property int maxChars: 16

                spacing: -2
                Repeater {
                    model: String(vt.value).slice(0, vt.maxChars).split("")
                    Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData === " " ? "·" : modelData
                        color: vt.textColor
                        font {
                            family: root.fontFam
                            pixelSize: vt.size
                            bold: vt.bold
                        }
                    }
                }
            }

            ColumnLayout {
                id: vertCapsule
                anchors.centerIn: parent
                width: root.pillH
                spacing: 7
                visible: (!root.expanded || (root.cfg.pillKeepVisible && !root.settingsMode)) && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
                opacity: root.pillSide ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animFast } }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: mediaCol.implicitHeight
                    visible: root.mediaActive

                ColumnLayout {
                    id: mediaCol
                    anchors.fill: parent
                    spacing: 5

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 7
                        color: Pal.a(0.08)

                        RoundImage {
                            id: vertArt
                            anchors.fill: parent
                            source: root.mediaArt
                            radius: 7
                            sourceWidth: 64
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !vertArt.ready
                            text: "󰝚"
                            color: root.colMuted
                            font { family: root.fontFam; pixelSize: 11 }
                        }
                    }

                    VertText {
                        Layout.alignment: Qt.AlignHCenter
                        value: root.player ? String(root.player.trackTitle || "") : ""
                        textColor: root.colFg
                        size: root.fontSize - 3
                        bold: true
                        maxChars: 10
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 28
                        WaveBars {
                            anchors.centerIn: parent
                            width: 28
                            height: 14
                            rotation: -90
                            barColor: root.colFg
                            active: root.pillSide && !root.expanded && (root.player ? root.player.isPlaying : false)
                        }
                    }

                }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            var t = root.player ? String(root.player.trackTitle || "") : "";
                            if (t.length === 0) return;
                            var p = mapToItem(null, width / 2, height / 2);
                            root.showTip(t, p.x, p.y);
                        }
                        onExited: root.hideTip(root.player
                                               ? String(root.player.trackTitle || "") : "")
                        onClicked: root.togglePage("main")
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    visible: root.recActive
                    color: root.recPaused ? root.colWarn : root.colCrit
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 1
                    visible: root.mediaActive
                    color: Pal.a(0.18)
                }

                VertText {
                    Layout.alignment: Qt.AlignHCenter
                    value: root.dayText
                    textColor: root.colMuted
                    size: root.fontSize - 2
                    bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.timeText.split(":")[0] || ""
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (root.timeText.split(":")[1] || "").replace(/[^0-9]/g, "")
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: String(root.wsId)
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.kbLayout
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 4; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadGpu >= 0)
                    text: (root.loadCpu >= 0 ? "C" + root.loadCpu + "%" + (root.loadTempCpu >= 0 ? "/" + root.loadTempCpu + "°" : "") : "")
                          + (root.loadGpu >= 0 ? " G" + root.loadGpu + "%" + (root.loadTempGpu >= 0 ? "/" + root.loadTempGpu + "°" : "") : "")
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.batteryPresent
                    text: root.batteryIcon
                    color: root.batteryCharging || root.acOnline ? root.colOk
                         : root.batteryPct <= 15 ? root.colCrit : root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 1 }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.batteryPresent
                    text: root.batteryPct
                    color: root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
            }

        Item {
            id: dragHandle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            z: 60
            visible: root.cfg.pillDrag && root.expanded && root.page === "main"
                     && !root.settingsMode

            Rectangle {
                anchors.centerIn: parent
                width: 46
                height: 4
                radius: 2
                color: root.pillDragging ? root.colOn
                     : (handleMa.containsMouse ? Pal.a(0.45)
                                               : Pal.a(0.18))
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            MouseArea {
                id: handleMa
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: root.pillDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0

                onPressed: mouse => {
                    var p = mapToItem(null, mouse.x, mouse.y);
                    handleMa.pressX = p.x;
                    handleMa.pressY = p.y;
                    root.pillDragging = true;
                }
                onPositionChanged: mouse => {
                    if (!root.pillDragging) return;
                    var p = mapToItem(null, mouse.x, mouse.y);
                    root.dragDX = p.x - handleMa.pressX;
                    root.dragDY = p.y - handleMa.pressY;
                    root.dragEdge = root.edgeAt(capsule.x + root.dragDX + capsule.width / 2,
                                                capsule.y + root.dragDY + capsule.height / 2);
                }
                onReleased: root.dropPill()
                onCanceled: root.dropPill()
            }
        }

        Row {
            id: islandTabs
            parent: (root.cfg.pillKeepVisible && root.expanded && !root.settingsMode) ? detachedPanel : capsule
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.leftMargin: 16
            z: 65
            spacing: 6
            visible: root.expanded && !root.settingsMode && (root.page === "main" || root.page === "chat" || root.page === "vpn")
            Repeater {
                model: [{page:"main", title:root.tr("Home"), icon:0xF02DC}, {page:"zapfast", title:"WhatsApp", icon:0xF05A3}]
                delegate: Rectangle {
                    required property var modelData
                    width: root.page === modelData.page ? tabText.implicitWidth + 48 : 40
                    height: 34; radius: 17
                    color: root.page === modelData.page ? Pal.a(0.12) : "transparent"
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        IslandTabIcon { anchors.verticalCenter: parent.verticalCenter; width: 19; height: 19; kind: modelData.page === "main" ? "home" : "chat"; tint: root.page === modelData.page ? root.colFg : root.colMuted }
                        Text { id: tabText; anchors.verticalCenter: parent.verticalCenter; visible: root.page === modelData.page; text: modelData.title; color: root.colFg; font { family: root.fontBody; pixelSize: 12; bold: true } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (modelData.page === "zapfast") { root.collapse(); Quickshell.execDetached(["loka-zapfast"]); } else { root.page = modelData.page; root.holdOpen = false; } } }
                }
            }
        }

        Rectangle {
            id: vpnTab
            parent: (root.cfg.pillKeepVisible && root.expanded && !root.settingsMode) ? detachedPanel : capsule
            anchors.top: parent.top; anchors.topMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 18
            z: 65; width: 34; height: 34; radius: 17
            visible: false
            color: root.vpnConnected ? root.colFg : (root.page === "vpn" ? Pal.a(0.12) : "transparent")
            Behavior on color { ColorAnimation { duration: root.animFast } }
            Text { anchors.centerIn: parent; text: root.vpnBusy ? "···" : root.vpnCountry; color: root.vpnConnected ? root.colBg : root.colFg; font { family: root.fontBody; pixelSize: 12; bold: true } }
            Canvas {
                anchors.fill: parent; anchors.margins: -3; visible: root.vpnBusy
                onPaint: { var c = getContext("2d"); c.reset(); c.strokeStyle = root.colFg; c.lineWidth = 2; c.lineCap = "round"; c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 1.4); c.stroke(); }
                NumberAnimation on rotation { from: 0; to: 360; duration: 700; loops: Animation.Infinite; running: root.vpnBusy && !root.noMotion }
            }
            MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || (!root.cfg.vpnPreferred && !root.cfg.vpnPreferredClient)) { root.page = "vpn"; root.holdOpen = true; }
                    else root.togglePreferredVpn();
                }
            }
        }

        Loader {
            id: contentLoader
            z: 10
            parent: (root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || detachedPanel.opacity > 0.005)) ? detachedPanel : capsule
            anchors.top: parent ? parent.top : undefined
            anchors.topMargin: (root.page === "main" || root.page === "chat" || root.page === "vpn") && !root.settingsMode ? 55 : 15
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            width: (root.settingsMode ? root.settingsW : root.panelW) - 30
            active: (root.expanded || capsule.height > root.pillH + 4 || (root.cfg.pillKeepVisible && detachedPanel.opacity > 0.005))
                    && !root.recPickActive && !root.btToastActive && !root.wifiToastActive
                    && !root.acToastActive && !root.voxActive
            visible: !root.recPickActive && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.voxActive
            focus: true
            onLoaded: if (item) item.forceActiveFocus()
            Keys.onEscapePressed: {
                var it = contentLoader.item;
                if (it && typeof it.goBack === "function" && it.goBack()) return;
                root.collapse();
            }
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Q || event.key === Qt.Key_W) &&
                    (event.modifiers & Qt.MetaModifier)) {
                    if (root.cfg.closePanaceaFirst)
                        root.collapse();
                    else
                        root.closeActiveWindow();
                    event.accepted = true;
                }
            }
            opacity: root.expanded ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.expanded ? root.animFast : 90; easing.type: Easing.OutCubic }
            }

            sourceComponent: root.page === "settings" ? settingsComp
                           : root.page === "clip"     ? clipComp
                           : root.page === "power"    ? powerComp
                           : root.page === "notif"    ? notifComp
                           : root.page === "audio"    ? audioComp
                           : root.page === "cal"      ? calComp
                           : root.page === "record"   ? recordComp
                                                      : controlsComp
        }
        Component { id: controlsComp; ControlsView { sys: root } }
        Component { id: settingsComp; SettingsView { sys: root; tab: root.settingsTab } }
        Component { id: clipComp;     ClipboardView { sys: root } }
        Component { id: powerComp;    PowerView { sys: root } }
        Component { id: notifComp;    NotificationsView { sys: root } }
        Component { id: audioComp;    AudioView { sys: root } }
        Component { id: calComp;      CalendarView { sys: root } }
        Component { id: recordComp;   RecordView { sys: root } }
    }

    Rectangle {
        id: detachedPanel
        z: 50
        readonly property bool showMe: root.cfg.pillKeepVisible && !root.settingsMode && root.expanded

        visible: root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || opacity > 0.005)
        opacity: showMe ? 1 : 0
        scale: showMe ? 1 : 0.96

        transformOrigin: root.pillAtBottom ? Item.Bottom
                       : root.pillAtLeft   ? Item.Left
                       : root.pillAtRight  ? Item.Right
                                           : Item.Top

        transform: Translate {
            y: root.pillAtBottom
               ? (detachedPanel.showMe ? 0 : 10)
               : (detachedPanel.showMe ? 0 : -10)
            x: root.pillAtRight
               ? (detachedPanel.showMe ? 0 : 10)
               : root.pillAtLeft
               ? (detachedPanel.showMe ? 0 : -10)
               : 0

            Behavior on y {
                NumberAnimation {
                    duration: detachedPanel.showMe ? root.animMs : root.animFast
                    easing.type: detachedPanel.showMe
                                 ? (root.animBounce > 0 ? Easing.OutBack : Easing.OutCubic)
                                 : Easing.OutCubic
                    easing.overshoot: root.easeOvershoot
                }
            }
            Behavior on x {
                NumberAnimation {
                    duration: detachedPanel.showMe ? root.animMs : root.animFast
                    easing.type: detachedPanel.showMe
                                 ? (root.animBounce > 0 ? Easing.OutBack : Easing.OutCubic)
                                 : Easing.OutCubic
                    easing.overshoot: root.easeOvershoot
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: detachedPanel.showMe ? root.animFade : Math.round(root.animFade * 0.75)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: detachedPanel.showMe ? root.animMs : root.animFast
                easing.type: detachedPanel.showMe
                             ? (root.animBounce > 0 ? Easing.OutBack : Easing.OutCubic)
                             : Easing.OutCubic
                easing.overshoot: root.easeOvershoot
            }
        }

        readonly property real panelGap: root.cfg.islandGap > 0 ? root.cfg.islandGap : 10

        width: (root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || opacity > 0.005)) ? root.panelW : 0

        readonly property real detachedTargetH: Math.min(capsule.contentH, root.cfg.expandedH)
        height: (root.cfg.pillKeepVisible && !root.settingsMode && (root.expanded || opacity > 0.005))
                ? Math.min(detachedTargetH, root.height - (capsule.y + capsule.height + panelGap + 24))
                : 0
        Behavior on height { NumberAnimation { duration: root.animQuick; easing.type: Easing.OutCubic } }

        x: root.pillSide
           ? (root.pillAtLeft  ? capsule.x + capsule.width + panelGap
              : root.pillAtRight ? capsule.x - width - panelGap
              : Math.max(12, Math.min(root.width - width - 12, capsule.x + (capsule.width - width) / 2)))
           : Math.max(12, Math.min(root.width - width - 12, capsule.x + (capsule.width - width) / 2))

        y: root.pillAtBottom
           ? capsule.y - height - panelGap
           : root.pillAtTop
              ? capsule.y + capsule.height + panelGap
              : Math.max(12, Math.min(root.height - height - 12, capsule.y + (capsule.height - height) / 2))

        radius: root.cfg.islandRadius > 0 ? root.cfg.islandRadius : 24
        color: root.colBg
        border.width: 0
        clip: true

        HoverHandler {
            id: detachedHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                } else if (!capsuleHover.hovered && !root.holdOpen) {
                    collapseTimer.restart();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }
    }

    property string tipText: ""
    property real   tipX: 0
    property real   tipY: 0
    function showTip(text, x, y) { root.tipText = text; root.tipX = x; root.tipY = y; }
    function hideTip(text) { if (root.tipText === text) root.tipText = ""; }

    Rectangle {
        id: globalTip
        z: 200
        visible: opacity > 0.01
        opacity: root.tipText.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 130 } }

        width: globalTipText.implicitWidth + 20
        height: 26
        radius: 13
        x: Math.max(6, root.tipX - width - 10)
        y: root.tipY - height / 2
        color: Qt.rgba(0.04, 0.04, 0.05, 0.98)
        border.color: root.colLine
        border.width: 1

        scale: root.tipText.length > 0 ? 1 : 0.92
        transformOrigin: Item.Right
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Text {
            id: globalTipText
            anchors.centerIn: parent
            text: root.tipText
            color: root.colFg
            font { family: root.fontFam; pixelSize: 11 }
        }
    }

    NotchCorner {
        id: notchBefore
        side: root.pillSide ? (root.pillAtLeft ? "right" : "left") : "left"
        fill: root.colBg
        r: root.cornerR
        transform: Scale {
            origin.y: root.cornerR / 2
            yScale: root.pillSide ? -1 : (root.pillAtBottom ? -1 : 1)
        }
        x: root.pillAtLeft  ? 0
         : root.pillAtRight ? parent.width - width
                            : Math.round(capsule.x) - width
        y: root.pillSide ? capsule.y - height
         : root.pillAtBottom ? parent.height - height : 0
        opacity: root.cornersOn ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
    NotchCorner {
        id: notchAfter
        side: root.pillSide ? (root.pillAtLeft ? "right" : "left") : "right"
        fill: root.colBg
        r: root.cornerR
        transform: Scale {
            origin.y: root.cornerR / 2
            yScale: root.pillSide ? 1 : (root.pillAtBottom ? -1 : 1)
        }
        x: root.pillAtLeft  ? 0
         : root.pillAtRight ? parent.width - width
                            : Math.round(capsule.x + capsule.width)
        y: root.pillSide ? capsule.y + capsule.height
         : root.pillAtBottom ? parent.height - height : 0
        opacity: root.cornersOn ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
}

Item {
    Connections {
        target: Quickshell
        function onClipboardTextChanged() { clipDebounce.restart(); }
    }
    Timer { id: clipDebounce; interval: 150; onTriggered: { clipProc.running = false; clipProc.running = true; } }
    Process { id: clipProc; command: ["loka-clipstore"] }
}
LokaBar { sys: root }

LazyLoader {
    id: worldWallsLoader
    active: false
    WorldWalls {
        sys: root
        Component.onCompleted: if (root.worldWallsWanted !== "") { show(root.worldWallsWanted); root.worldWallsWanted = ""; }
        onOpenChanged: if (!open) closeTimer.restart()
        Timer { id: closeTimer; interval: 4000; onTriggered: if (worldWallsLoader.item && !worldWallsLoader.item.open) worldWallsLoader.active = false }
    }
}

}
