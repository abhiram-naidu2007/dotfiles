import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.SystemTray

PanelWindow {
    id: bar
    required property var sys

    anchors { top: true; left: true; right: true }
    implicitHeight: bar.top + bar.pillH + 6
    exclusiveZone: 0
    color: "transparent"
    visible: !Compositor.isFullscreen
    mask: Region {
        Region { item: leftRow }
        Region { item: rightRow }
    }

    readonly property int top: 8
    readonly property int edge: 8
    readonly property int pillH: World.pillH
    readonly property int gap: 8
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property var pal: bar.sys.ricePal || ({})
    function pc(key, fallback) { return bar.pal[key] ? bar.pal[key] : fallback; }
    readonly property color bg: Qt.alpha(bar.pc("surface", "#141414"), 0.94)
    readonly property color line: bar.pc("surface1", Pal.a(0.14))
    readonly property color lineHot: bar.pc("surface2", Pal.a(0.30))
    readonly property color text1: bar.pc("fg", bar.sys.colFg)
    readonly property color text2: bar.pc("subtext", Pal.a(0.68))
    readonly property color text3: bar.pc("dim", Pal.a(0.44))
    readonly property color faint: bar.pc("surface1", Pal.a(0.13))
    readonly property color crit: bar.pc("crit", bar.sys.colCrit)
    readonly property color ok: bar.pc("ok", "#4fd18b")
    readonly property color on: bar.pc("accent", bar.sys.colOn)
    readonly property color on2: bar.pc("accent2", bar.sys.colOn)
    readonly property color onText: bar.pc("crust", bar.sys.colBg)
    readonly property color warn: bar.pc("warn", "#f2b544")

    readonly property real islandHalf: 230
    readonly property real leftRoom: bar.width / 2 - islandHalf - bar.edge

    property int cpu: -1
    property int mem: -1
    property int gpu: -1
    Process {
        running: true
        command: ["loka-stats", "3"]
        stdout: SplitParser {
            onRead: line => {
                var a = line.split("|");
                if (a.length < 6) return;
                bar.cpu = parseInt(a[0]);
                bar.mem = parseInt(a[1]);
                var ig = a[3] === "" ? -1 : parseInt(a[3]);
                var dg = /^[0-9]+$/.test(a[4]) ? parseInt(a[4]) : -1;
                bar.gpu = Math.max(ig, dg);
            }
        }
    }

    readonly property string home: Quickshell.env("HOME")
    property string riceScene: "picture"
    property string riceLive: "off"
    FileView { id: sceneFile; path: bar.home + "/.local/state/rice/scene"; watchChanges: true; onFileChanged: reload(); onLoaded: bar.riceScene = sceneFile.text().trim() || "picture" }
    FileView { id: liveFile; path: bar.home + "/.local/state/rice/live"; watchChanges: true; onFileChanged: reload(); onLoaded: bar.riceLive = liveFile.text().trim() || "off" }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    property string title: ""
    property string appClass: ""

    function refreshTitle() { tree.running = false; tree.running = true; }
    Process {
        id: tree
        command: ["i3-msg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t;
                try { t = JSON.parse(this.text); } catch (e) { return; }
                var st = [t], f = null;
                while (st.length) {
                    var n = st.pop();
                    if (n.focused) { f = n; break; }
                    (n.nodes || []).concat(n.floating_nodes || []).forEach(function (c) { st.push(c); });
                }
                bar.title = f && f.window ? (f.name || "") : "";
                bar.appClass = f && f.window && f.window_properties ? (f.window_properties.class || "") : "";
            }
        }
    }
    Connections {
        target: I3
        function onRawEvent(ev) {
            if (ev.type === "window") {
                var e = {};
                try { e = JSON.parse(ev.data); } catch (x) {}
                var c = e.container || {};
                if (c.focused && (e.change === "focus" || e.change === "title" || e.change === "new")) {
                    bar.title = c.name || "";
                    bar.appClass = c.window_properties ? (c.window_properties.class || "") : "";
                } else if (e.change === "close") bar.refreshTitle();
            } else if (ev.type === "workspace") bar.refreshTitle();
        }
    }
    Component.onCompleted: refreshTitle()

    component Pill: Item {
        id: p
        default property alias content: row.data
        property int pad: World.toon ? 14 : 12
        property alias spacing: row.spacing
        property bool hot: ma.containsMouse
        property bool active: false
        property color color: active ? bar.on : bar.bg
        property real borderW: active ? 0 : World.border
        signal clicked(var mouse)
        signal scrolled(var wheel)
        implicitWidth: row.implicitWidth + pad * 2 + (World.sakuga ? 12 : 0)
        implicitHeight: World.pillH
        Behavior on implicitWidth { NumberAnimation { duration: World.dur; easing.type: World.easing; easing.overshoot: World.overshoot } }

        Rectangle {
            visible: World.lift
            x: 0; y: 3
            width: parent.width; height: parent.height
            radius: World.radius
            color: Qt.darker(p.color, 1.9)
        }
        Rectangle {
            id: face
            anchors.fill: parent
            radius: Math.min(World.radius, height / 2)
            color: p.color
            border.width: p.borderW
            border.color: p.hot ? bar.lineHot : bar.line
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, World.skew, 0, -World.skew * p.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            Behavior on color { ColorAnimation { duration: World.dur } }
            Behavior on border.color { ColorAnimation { duration: World.dur } }
            Column {
                visible: World.lacquer
                anchors.fill: parent
                anchors.topMargin: 6
                anchors.leftMargin: face.radius * 0.6
                anchors.rightMargin: face.radius * 0.6
                spacing: 7
                Repeater {
                    model: 3
                    Rectangle { width: parent.width; height: 1; color: Qt.alpha(bar.on, 0.22) }
                }
            }
            Rectangle {
                visible: World.toon
                x: parent.radius * 0.6; y: 4
                width: parent.width - parent.radius * 1.2; height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.14)
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: m => p.clicked(m)
            onWheel: w => p.scrolled(w)
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
        }
    }

    component Glyph: Text {
        property int size: 15
        font.family: bar.iconFont
        font.pixelSize: size
        color: bar.text2
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        renderType: Text.NativeRendering
    }

    component Txt: Text {
        property bool caps: World.caps
        property bool num: false
        property int size: World.meridian ? 12 : 13
        property int weight: World.textWeight
        font.family: World.text
        font.pixelSize: size
        font.weight: weight
        font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: World.tracking
        font.features: num ? { "tnum": 1 } : {}
        font.variableAxes: World.textAxes
        font.italic: World.sakuga && weight >= Font.Bold
        color: bar.text1
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }

    Row {
        id: leftRow
        x: bar.edge
        y: bar.top
        spacing: bar.gap

        Pill {
            pad: 10
            spacing: 12
            color: bar.on
            borderW: 0
            Glyph {
                text: "\u{f041d}"
                size: 16
                color: bar.onText
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => m.button === Qt.RightButton ? bar.run("~/.config/rofi/scripts/launcher.sh files")
                                 : m.button === Qt.MiddleButton ? bar.run("~/.local/bin/rice art")
                                 : bar.sys.toggleLauncher()
                }
            }
            Glyph {
                text: "\u{f059f}"
                size: 16
                color: bar.onText
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => m.button === Qt.RightButton ? bar.run("thorium-browser --new-window")
                                 : m.button === Qt.MiddleButton ? bar.run("~/.config/i3/scripts/browser.sh")
                                 : bar.run("~/.config/rofi/scripts/launcher.sh web")
                }
            }
        }

        Pill {
            pad: 13
            spacing: 9
            onScrolled: w => {
                var list = bar.sys.wsList, i = list.indexOf(bar.sys.wsId);
                var n = w.angleDelta.y < 0 ? Math.min(list.length - 1, i + 1) : Math.max(0, i - 1);
                if (list.length) bar.sys.gotoWorkspace(list[n]);
            }
            Repeater {
                model: bar.sys.wsList
                Item {
                    id: ws
                    required property var modelData
                    readonly property bool here: modelData === bar.sys.wsId
                    readonly property string kind: World.workspace
                    width: kind === "akshara" ? (here ? akshara.implicitWidth : 6)
                         : kind === "bubble" ? (here ? 14 : 8)
                         : kind === "slash" ? (here ? 22 : 7)
                         : (here ? 18 : 5)
                    height: World.pillH
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: here ? 1 : (wsMa.containsMouse ? 0.85 : 0.5)
                    Behavior on width { NumberAnimation { duration: World.dur; easing.type: World.easing; easing.overshoot: World.overshoot } }
                    Rectangle {
                        visible: !(ws.kind === "akshara" && ws.here)
                        anchors.centerIn: parent
                        width: parent.width
                        height: ws.kind === "bubble" ? width : ws.kind === "dash" ? (ws.here ? 4 : 5) : ws.kind === "slash" ? 6 : 6
                        radius: ws.kind === "dash" || ws.kind === "slash" ? 0 : height / 2
                        color: ws.here ? bar.on : bar.text2
                        border.width: ws.kind === "bubble" && ws.here ? 2 : 0
                        border.color: Qt.lighter(bar.on, 1.3)
                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, ws.kind === "slash" ? -0.9 : 0, 0, ws.kind === "slash" ? 0.9 * 3 : 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    }
                    Text {
                        id: akshara
                        visible: ws.kind === "akshara" && ws.here
                        anchors.centerIn: parent
                        text: "అ"
                        font.family: World.display
                        font.pixelSize: 22
                        color: bar.on
                        renderType: Text.NativeRendering
                    }
                    MouseArea { id: wsMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.sys.gotoWorkspace(ws.modelData) }
                }
            }
        }

        Item {
            id: titleBox
            readonly property var entry: bar.appClass !== "" ? DesktopEntries.heuristicLookup(bar.appClass) : null
            readonly property string iconSrc: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
            readonly property string shown: {
                var t = bar.title;
                var n = entry && entry.name ? entry.name : "";
                if (n && t.endsWith(" - " + n)) t = t.slice(0, -(n.length + 3));
                if (n && t.endsWith(" — " + n)) t = t.slice(0, -(n.length + 3));
                return t;
            }
            visible: bar.title !== ""
            width: titleRow.implicitWidth + 26
            height: bar.pillH
            Rectangle {
                anchors.fill: parent
                radius: Math.min(World.radius, height / 2)
                color: Qt.alpha(bar.bg, 0.78)
                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, World.skew, 0, -World.skew * World.pillH / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            }
            Row {
                id: titleRow
                x: 13
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Image {
                    visible: titleBox.iconSrc !== ""
                    width: 16; height: 16
                    sourceSize: Qt.size(32, 32)
                    source: titleBox.iconSrc
                    anchors.verticalCenter: parent.verticalCenter
                }
                Glyph {
                    visible: titleBox.iconSrc === ""
                    text: "\u{f05af}"
                    size: 14
                    color: bar.on2
                }
                Txt {
                    text: titleBox.shown
                    size: 13
                    caps: false
                    weight: Font.Medium
                    font.italic: false
                    color: bar.text1
                    width: Math.min(implicitWidth, Math.max(80, Math.min(360, bar.leftRoom - 200)))
                }
            }
        }
    }

    Row {
        id: rightRow
        x: bar.width - bar.edge - width
        y: bar.top
        spacing: bar.gap

        Pill {
            readonly property int shown: {
                var n = 0;
                for (var i = 0; i < trayRep.count; i++) if (trayRep.itemAt(i) && trayRep.itemAt(i).visible) n++;
                return n;
            }
            visible: shown > 0
            spacing: 10
            Repeater {
                id: trayRep
                model: SystemTray.items
                Image {
                    required property var modelData
                    visible: ["nm-applet", "blueman", "NetworkManager", "xfce4-clipman"].indexOf(String(modelData.id)) < 0
                    width: visible ? 16 : 0; height: 16
                    sourceSize: Qt.size(32, 32)
                    source: modelData.icon
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => {
                            if (m.button === Qt.LeftButton && String(modelData.id).toLowerCase().indexOf("zapfast") >= 0) Quickshell.execDetached(["loka-zapfast"]);
                            else if (m.button === Qt.LeftButton && !modelData.onlyMenu) modelData.activate();
                            else if (m.button === Qt.MiddleButton) modelData.secondaryActivate();
                            else if (modelData.hasMenu) modelData.display(bar, parent.mapToItem(null, 0, 0).x, bar.top + bar.pillH + 6);
                        }
                    }
                }
            }
        }

        Pill {
            id: statPill
            visible: bar.cpu >= 0
            spacing: 12
            onClicked: bar.sys.togglePage("main")
            Repeater {
                model: [
                    { g: World.labels[0], v: bar.cpu, c: bar.pc("blue", bar.text2) },
                    { g: World.labels[1], v: bar.mem, c: bar.pc("magenta", bar.text2) },
                    { g: World.labels[2], v: bar.gpu, c: bar.pc("cyan", bar.text2) }
                ]
                Row {
                    required property var modelData
                    visible: modelData.v >= 0
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        visible: !World.labelGlyphs
                        text: modelData.g
                        size: 11; weight: Font.Bold; caps: true
                        color: modelData.v >= 90 ? bar.crit : modelData.v >= 70 ? bar.warn : modelData.c
                    }
                    Glyph {
                        visible: World.labelGlyphs
                        text: modelData.g
                        size: 14
                        color: modelData.v >= 90 ? bar.crit : modelData.v >= 70 ? bar.warn : modelData.c
                    }
                    Txt {
                        text: modelData.v
                        num: true; size: 13
                        width: 20
                        horizontalAlignment: Text.AlignRight
                        color: modelData.v >= 90 ? bar.crit : bar.text1
                    }
                }
            }
        }

        Pill {
            id: wifiPill
            active: bar.sys.expanded && bar.sys.page === "wifi"
            onClicked: m => m.button === Qt.RightButton ? Quickshell.execDetached(["nm-connection-editor"]) : bar.sys.togglePage("wifi")
            Glyph {
                text: !bar.sys.wifiOn ? "\u{f092e}" : bar.sys.wifiSsid === "" ? "\u{f092b}"
                    : bar.sys.wifiQuality > 66 ? "\u{f0928}" : bar.sys.wifiQuality > 33 ? "\u{f0925}" : "\u{f091f}"
                color: wifiPill.active ? bar.onText : (!bar.sys.wifiOn || bar.sys.wifiSsid === "") ? bar.crit : bar.text1
            }
        }

        Pill {
            id: btPill
            active: bar.sys.expanded && bar.sys.page === "bt"
            onClicked: bar.sys.togglePage("bt")
            Glyph {
                text: !bar.sys.btOn ? "\u{f00b2}" : bar.sys.btConnectedName !== "" ? "\u{f00b1}" : "\u{f00af}"
                color: btPill.active ? bar.onText : bar.sys.btConnectedName !== "" ? bar.text1 : bar.text3
            }
            Txt {
                visible: bar.sys.btConnectedBattery > 0
                text: bar.sys.btConnectedBattery + "%"
                num: true; size: 12
                color: btPill.active ? bar.onText : bar.text2
            }
        }

        Pill {
            id: volPill
            readonly property real vol: bar.sys.sinkAudio ? bar.sys.sinkAudio.volume : 0
            readonly property bool muted: bar.sys.sinkAudio ? bar.sys.sinkAudio.muted : false
            active: bar.sys.expanded && bar.sys.page === "audio"
            spacing: 7
            onClicked: m => {
                if (m.button === Qt.MiddleButton && bar.sys.sinkAudio) bar.sys.sinkAudio.muted = !bar.sys.sinkAudio.muted;
                else if (m.button === Qt.RightButton) bar.run("pavucontrol");
                else bar.sys.togglePage("audio");
            }
            onScrolled: w => {
                var a = bar.sys.sinkAudio;
                if (!a) return;
                a.muted = false;
                a.volume = Math.max(0, Math.min(1, a.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
            Glyph {
                text: volPill.muted ? "\u{f075f}" : volPill.vol > 0.66 ? "\u{f057e}" : volPill.vol > 0.33 ? "\u{f0580}" : "\u{f057f}"
                color: volPill.active ? bar.onText : volPill.muted ? bar.crit : bar.pc("bryellow", bar.text1)
            }
            Txt {
                text: volPill.muted ? "MUTE" : Math.round(volPill.vol * 100)
                num: true; size: 13; caps: volPill.muted
                width: 28
                color: volPill.active ? bar.onText : volPill.muted ? bar.crit : bar.text1
            }
        }

        Pill {
            id: hpPill
            visible: bar.sys.batteryPresent
            readonly property int pct: bar.sys.batteryPct
            readonly property bool charging: bar.sys.batteryCharging
            readonly property color hp: charging ? bar.ok : pct <= 20 ? bar.crit : pct <= 50 ? bar.warn : bar.ok
            active: bar.sys.expanded && bar.sys.page === "main"
            spacing: 8
            onClicked: m => m.button === Qt.RightButton ? bar.run("~/.config/i3/scripts/settings.sh") : bar.sys.togglePage("main")
            Txt { visible: World.hp !== "lamp"; text: "HP"; size: 11; weight: Font.Bold; caps: true; color: hpPill.active ? bar.onText : bar.text2 }
            Rectangle {
                visible: World.hp === "bar"
                width: 62; height: 8; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: hpPill.active ? Pal.b(0.25) : bar.faint
                Rectangle {
                    width: Math.max(4, parent.width * hpPill.pct / 100)
                    height: parent.height; radius: 4
                    color: hpPill.hp
                    Behavior on width { NumberAnimation { duration: 440; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
            Row {
                visible: World.hp === "blocks"
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: 10
                    Rectangle {
                        required property int index
                        width: 4; height: 11
                        color: index < Math.ceil(hpPill.pct / 10) ? hpPill.hp : bar.faint
                    }
                }
            }
            Row {
                visible: World.hp === "hearts"
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: 5
                    Glyph {
                        required property int index
                        readonly property real fill: Math.max(0, Math.min(1, hpPill.pct / 20 - index))
                        text: fill >= 0.75 ? "\u{f02d1}" : fill >= 0.25 ? "\u{f06de}" : "\u{f02d5}"
                        size: 15
                        color: fill >= 0.25 ? (hpPill.pct <= 20 ? bar.crit : bar.pc("red", bar.crit)) : bar.text3
                    }
                }
            }
            Item {
                visible: World.hp === "lamp"
                width: 26; height: 22
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    id: flame
                    property real lvl: 0.45 + 0.55 * hpPill.pct / 100
                    text: "\u{f0238}"
                    font.family: bar.iconFont
                    font.pixelSize: 15
                    scale: lvl
                    transformOrigin: Item.Bottom
                    x: 13 - width / 2; y: 13 - height
                    color: hpPill.charging ? bar.on : hpPill.pct <= 20 ? bar.crit : bar.pc("bryellow", bar.warn)
                    renderType: Text.NativeRendering
                    Behavior on lvl { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }
                    SequentialAnimation on rotation {
                        running: World.katha && hpPill.charging
                        loops: Animation.Infinite
                        NumberAnimation { to: 5; duration: 520; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -5; duration: 520; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    x: 1; y: 12
                    width: 24; height: 8
                    radius: 4
                    color: bar.on
                }
                Rectangle {
                    x: 1; y: 12
                    width: 24; height: 3
                    color: bar.on
                }
                Rectangle {
                    x: 20; y: 11
                    width: 6; height: 4
                    radius: 2
                    color: Qt.darker(bar.on, 1.25)
                }
            }
            Txt {
                text: hpPill.pct + "%" + (hpPill.charging ? " +" : "")
                num: true; size: 13
                color: hpPill.active ? bar.onText : hpPill.pct <= 20 && !hpPill.charging ? bar.crit : bar.text1
            }
        }

        Pill {
            id: lookPill
            spacing: 10
            readonly property bool pic: bar.riceScene === "picture"
            readonly property bool moving: !pic && (bar.riceLive === "on" || bar.riceLive === "always")
            readonly property string mood: bar.pal.mode || "night"
            Glyph {
                text: lookPill.pic ? "\u{f02e9}" : lookPill.moving ? "\u{f040a}" : "\u{f03e4}"
                color: lookPill.moving ? bar.on : bar.text3
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => m.button === Qt.RightButton || lookPill.pic ? bar.sys.openWorldWalls("") : bar.run("~/.local/bin/rice live toggle")
                    onWheel: w => bar.run("~/.local/bin/rice scene " + (w.angleDelta.y > 0 ? "next" : "prev"))
                }
            }
            Txt {
                visible: !lookPill.pic
                text: lookPill.moving ? "live" : "still"
                size: 12
                color: lookPill.moving ? bar.text1 : bar.text3
            }
            Glyph {
                text: lookPill.mood === "paper" ? "\u{f00ba}" : "\u{f03d8}"
                color: lookPill.mood === "paper" ? bar.text1 : bar.on
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => m.button === Qt.RightButton ? bar.run("~/.local/bin/rice menu") : bar.run("~/.local/bin/rice mode next")
                }
            }
        }

        Pill {
            id: pwrPill
            pad: 9
            color: bar.on
            borderW: 0
            active: bar.sys.expanded && bar.sys.page === "power"
            onClicked: m => m.button === Qt.RightButton ? bar.run("~/.config/i3/scripts/powermenu.sh") : bar.sys.togglePage("power")
            Glyph { text: "\u{f0425}"; color: bar.onText }
        }
    }
}
