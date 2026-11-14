pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Item {
    id: view
    property var sys

    property bool preview: false
    property var ccOrderOverride: null

    readonly property var ccDefault: ["clock", "toggles", "sliders", "media", "power", "quick", "tray"]
    readonly property var ccOrder: {
        if (view.ccOrderOverride) return view.ccOrderOverride;
        var saved = String(view.sys.cfg.ccLayout || "").split(",").filter(x => x.length);
        var out = saved.filter(id => view.ccDefault.indexOf(id) >= 0);
        view.ccDefault.forEach(id => { if (out.indexOf(id) < 0) out.push(id); });
        return out;
    }
    function ccBlock(id) {
        for (var i = 0; i < mainPage.children.length; i++)
            if (mainPage.children[i].objectName === "cc-" + id) return mainPage.children[i];
        return null;
    }
    function ccRow(id) {
        var i = view.ccOrder.indexOf(id);
        return i < 0 ? view.ccDefault.indexOf(id) : i;
    }

    function fmtTime(sec) {
        var t = Math.max(0, Math.floor(sec));
        var h = Math.floor(t / 3600);
        var m = Math.floor((t % 3600) / 60);
        var s = t % 60;
        var mm = h > 0 && m < 10 ? "0" + m : String(m);
        return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" + s : String(s));
    }

    implicitHeight: stack.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()

    function goBack() {
        if (view.sys.page === "netmenu") {
            view.sys.page = "wifi";
            return true;
        }
        if (view.sys.page === "wifi" || view.sys.page === "bt"
            || view.sys.page === "battery") {
            view.sys.page = "main";
            return true;
        }
        if (view.sys.page === "traymenu") {
            view.sys.page = "main";
            view.sys.trayMenuItem = null;
            return true;
        }
        return false;
    }

    Keys.onEscapePressed: {
        if (!view.goBack()) view.sys.collapse();
    }

    component PowerSeg: Rectangle {
        property string icon: ""
        property string label: ""
        property string profile: ""
        property color accent: view.sys.colOn
        readonly property bool active: view.sys.powerProfile === profile

        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: 14
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                      : (segMa.containsMouse ? Pal.a(0.09)
                                             : Pal.a(0.05))
        border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.40)
                             : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        scale: segMa.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.icon
                color: parent.parent.active ? parent.parent.accent : "#ffffff"
                font { family: view.sys.fontFam; pixelSize: 17 }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: parent.parent.active ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 11; bold: parent.parent.active }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        MouseArea {
            id: segMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.setPowerProfile(parent.profile)
        }
    }

    component Tile: Rectangle {
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        signal iconClicked()
        signal bodyClicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 16
        color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : Pal.a(0.05)
        border.color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 11

            Rectangle {
                id: iconBtn
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: parent.parent.on ? parent.parent.accent : Pal.a(0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: iconMa.pressed ? 0.9 : (iconMa.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: iconBtn.parent.parent.icon
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }
                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: iconBtn.parent.parent.iconClicked()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.label
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.sub
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }

            Text {
                text: String.fromCodePoint(0xF0142)
                color: bodyMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 13 }
                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: bodyMa
            anchors.fill: parent
            anchors.leftMargin: 58
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    component IconBtn: Rectangle {
        property string glyph: ""
        property string tip: ""
        property color glyphColor: view.sys.colMuted
        property color activeColor: view.sys.colFg
        property bool active: false
        property int badge: 0
        signal act()

        implicitWidth: 44
        implicitHeight: 44
        radius: 13
        z: ibMa.containsMouse ? 10 : 0
        color: ibMa.containsMouse ? Pal.a(0.12) : Pal.a(0.05)
        border.color: active ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.5) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }

        scale: ibMa.pressed ? 0.9 : (ibMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        Glyph {
            anchors.fill: parent
            glyph: parent.glyph
            color: parent.active ? parent.activeColor
                 : ibMa.containsMouse ? view.sys.colFg : parent.glyphColor
            fontFam: view.sys.fontFam
            size: view.sys.iconSize - 2
        }

        Rectangle {
            width: 15; height: 15; radius: 8
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 2
            visible: parent.badge > 0
            color: view.sys.colOn
            Text {
                anchors.centerIn: parent
                text: parent.parent.badge > 9 ? "9+" : parent.parent.badge
                color: view.sys.fgOn(view.sys.colOn)
                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
            }
        }

        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }

        Rectangle {
            id: ibTip
            visible: opacity > 0.01
            opacity: (ibMa.containsMouse && parent.tip.length) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            width: ibTipText.implicitWidth + 20
            height: 26
            radius: 13
            x: (parent.width - width) / 2
            y: -height - 8
            color: Qt.rgba(0.04, 0.04, 0.05, 0.96)
            border.color: view.sys.colLine
            border.width: 1

            scale: ibMa.containsMouse ? 1 : 0.92
            transformOrigin: Item.Bottom
            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
            }

            Text {
                id: ibTipText
                anchors.centerIn: parent
                text: ibTip.parent.tip
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }
    }

    component ChargeWave: Canvas {
        property color tint: view.sys.colOk
        property real level: 0.5
        property real radius: 14
        property bool running: false
        property real phase: 0

        opacity: running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        onPhaseChanged: requestPaint()
        onLevelChanged: requestPaint()
        onTintChanged: requestPaint()

        Timer {
            interval: 45
            running: parent.running && parent.visible
            repeat: true
            onTriggered: parent.phase += 0.16
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) return;

            var r = Math.min(radius, Math.min(width, height) / 2);
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.arcTo(width, 0, width, height, r);
            ctx.arcTo(width, height, 0, height, r);
            ctx.arcTo(0, height, 0, 0, r);
            ctx.arcTo(0, 0, width, 0, r);
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

    component MiniTile: Rectangle {
        id: tile
        property string icon: ""
        property Component iconItem: null
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        property bool wave: false
        property real waveLevel: 0.5
        signal iconClicked()
        signal bodyClicked()

        readonly property bool solid: tile.on && !tile.wave
        readonly property color ink: tile.solid ? view.sys.fgOn(tile.accent)
                                                : view.sys.colFg

        implicitWidth: 140
        implicitHeight: 56
        radius: 14
        color: solid ? accent
             : on ? Qt.rgba(accent.r, accent.g, accent.b, 0.16)
                  : Pal.a(0.05)
        border.color: solid ? accent
                    : on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35)
                         : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        ChargeWave {
            anchors.fill: parent
            radius: parent.radius
            tint: parent.accent
            level: parent.waveLevel
            running: parent.wave
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 10
            spacing: 8

            Rectangle {
                id: miniIcon
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: tile.solid ? view.sys.colBg
                     : tile.on ? tile.accent
                               : Pal.a(0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: miniIconMa.pressed ? 0.9 : (miniIconMa.containsMouse ? 1.07 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                readonly property color ink: tile.solid ? "#ffffff"
                                           : tile.on ? view.sys.fgOn(tile.accent)
                                                     : "#ffffff"

                Text {
                    anchors.centerIn: parent
                    visible: tile.iconItem === null
                    text: tile.icon
                    color: miniIcon.ink
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }

                Loader {
                    id: iconLoader
                    anchors.centerIn: parent
                    active: tile.iconItem !== null
                    sourceComponent: tile.iconItem
                }

                Binding {
                    target: iconLoader.item
                    property: "color"
                    value: miniIcon.ink
                    when: iconLoader.item !== null
                }
                MouseArea {
                    id: miniIconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.iconClicked()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    color: tile.ink
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: tile.sub
                    color: tile.solid
                           ? Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.6)
                           : view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: 44
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    component BattStat: Rectangle {
        id: battstat

        property string label: ""
        property string value: ""

        implicitWidth: 90
        implicitHeight: 44
        Layout.fillWidth: true
        radius: 12
        color: Pal.a(0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: battstat.label
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 10 }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: battstat.value
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
            }
        }
    }

    component MediaBtn: Rectangle {
        property string icon: ""
        property bool primary: false
        property bool enabledAction: true
        signal act()

        implicitWidth: primary ? 42 : 34
        implicitHeight: primary ? 42 : 34
        radius: width / 2
        color: primary ? view.sys.colFg
              : (mbMa.containsMouse ? view.sys.colHover : Pal.a(0.08))
        opacity: enabledAction ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: mbMa.pressed ? 0.9 : (mbMa.containsMouse ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.primary ? view.sys.colBg : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: parent.primary ? 17 : 14 }
        }
        MouseArea {
            id: mbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabledAction
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }
    }

    component Track: Item {
        id: trk

        property real pos: 0
        property string icon: ""
        property string valueText: ""
        property real wheelStep: 0.05
        property bool dim: false

        signal setFrac(real frac)
        signal iconClicked()

        implicitHeight: 22

        readonly property real padL: trk.icon.length ? 22 : 0
        function fracAt(x) {
            return Math.max(0, Math.min(1, (x + trk.padL) / Math.max(1, trk.width)));
        }

        property bool live: false
        Component.onCompleted: liveTimer.start()
        Timer { id: liveTimer; interval: 260; onTriggered: trk.live = true }

        property real wheelFrom: -1
        Timer { id: wheelIdle; interval: 260; onTriggered: trk.wheelFrom = -1 }

        property real held: -1
        readonly property real shown: trk.held >= 0 ? trk.held : trk.pos
        Timer { id: heldIdle; interval: 400; onTriggered: trk.held = -1 }
        function put(frac) {
            trk.held = Math.max(0, Math.min(1, frac));
            heldIdle.restart();
            trk.setFrac(trk.held);
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Pal.a(0.12)
            clip: true

            Rectangle {
                width: Math.max(parent.height, parent.width * trk.shown)
                height: parent.height
                radius: height / 2
                color: view.sys.colFg
                opacity: trk.dim ? 0.45 : 1
                Behavior on width {
                    enabled: trk.live && !trkMa.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        Text {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: trk.icon.length > 0
            text: trk.icon
            color: view.sys.colBg
            font { family: view.sys.fontFam; pixelSize: 15 }
        }

        Text {
            id: trkVal
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            text: trk.valueText
            color: (trk.width * trk.shown) > (trk.width - trkVal.width - 12)
                   ? view.sys.colBg : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
        }

        MouseArea {
            id: trkMa
            anchors.fill: parent
            anchors.leftMargin: trk.padL
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => trk.put(trk.fracAt(mouse.x))
            onPositionChanged: mouse => { if (pressed) trk.put(trk.fracAt(mouse.x)); }
            onWheel: wheel => {
                var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                if (d === 0) return;
                var base = trk.wheelFrom >= 0 ? trk.wheelFrom : trk.shown;
                var steps = Math.round(base / trk.wheelStep) + (d > 0 ? 1 : -1);
                var next = Math.max(0, Math.min(1, steps * trk.wheelStep));
                trk.wheelFrom = next;
                wheelIdle.restart();
                trk.put(next);
            }
        }

        MouseArea {
            width: 22
            height: parent.height
            visible: trk.icon.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: trk.iconClicked()
        }
    }

    component VolCard: Rectangle {
        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Pal.a(0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            anchors.bottomMargin: 11
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Sound")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: view.sys.sinkName.length ? view.sys.sinkName
                                                   : view.sys.tr("No devices")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
            }

            Track {
                id: vol
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                readonly property var a: view.sys.sinkAudio

                pos: vol.a ? vol.a.volume : 0
                dim: vol.a ? vol.a.muted : true
                icon: !vol.a ? String.fromCodePoint(0xF075F)
                    : vol.a.muted ? String.fromCodePoint(0xF075F)
                    : vol.a.volume < 0.34 ? String.fromCodePoint(0xF057F)
                    : vol.a.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                          : String.fromCodePoint(0xF057E)
                valueText: !vol.a ? "—"
                    : vol.a.muted ? view.sys.tr("Muted")
                                  : Math.round(vol.shown * 100) + "%"
                onSetFrac: f => { if (vol.a) vol.a.volume = Math.round(f * 20) / 20; }
                onIconClicked: if (vol.a) vol.a.muted = !vol.a.muted
            }
        }
    }

    component BrightCard: Rectangle {
        id: brCard
        property string bid: ""
        property int    bpct: 0
        property string bname: ""

        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Pal.a(0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            anchors.bottomMargin: 8
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Brightness")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Item { Layout.fillWidth: true }
                Text {
                    Layout.maximumWidth: 130
                    visible: brCard.bname.length > 0
                    text: brCard.bname
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }

            Track {
                id: brTrk
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                pos: Math.max(0, Math.min(1, brCard.bpct / 100))
                icon: String.fromCodePoint(0xF00DD)
                valueText: Math.round(brTrk.shown * 100) + "%"
                onSetFrac: f => view.sys.brightSet(brCard.bid, Math.round(f * 20) * 5)
            }
        }
    }

    component ActionBtn: Rectangle {
        id: ab
        property string label: ""
        property string glyph: ""
        property bool on: false
        signal act()
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 10
        color: ab.on ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                     : (abMa.containsMouse ? view.sys.colHover : Pal.a(0.06))
        border.color: ab.on ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.5) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 130 } }
        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: ab.glyph.length > 0
                text: ab.glyph
                color: ab.on ? view.sys.colOn : view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
            Text {
                text: ab.label
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }
        MouseArea {
            id: abMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.act()
        }
    }

    function launch(cmd) { Quickshell.execDetached(cmd); view.sys.collapse(); }

    readonly property var btList: {
        var all = view.sys.btDevices ? view.sys.btDevices.values : [];
        var seen = {}, out = [];
        var mac = /^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i;
        for (var i = 0; i < all.length; i++) {
            var d = all[i];
            if (!d) continue;
            var known = d.connected || d.paired || d.bonded || d.pairing;
            var name = String(d.name || "");
            if (!known && (!name.length || mac.test(name))) continue;
            if (!known && seen[name]) continue;
            seen[name] = true;
            out.push(d);
        }
        out.sort(function (a, b) {
            var ra = a.connected ? 0 : (a.paired || a.bonded) ? 1 : 2;
            var rb = b.connected ? 0 : (b.paired || b.bonded) ? 1 : 2;
            return ra !== rb ? ra - rb : String(a.name).localeCompare(String(b.name));
        });
        return out;
    }

    component Header: RowLayout {
        id: rowlay

        property string title: ""
        property bool busy: false
        signal back()
        signal refresh()

        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 14
            color: backMa.containsMouse ? view.sys.colHover : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
            Text {
                anchors.centerIn: parent; text: String.fromCodePoint(0xF004D)
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
            MouseArea {
                id: backMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rowlay.back()
            }
        }
        Text {
            Layout.fillWidth: true
            text: parent.title
            color: view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 13; bold: true }
        }
        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 14
            color: refMa.containsMouse ? view.sys.colHover : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
            Text {
                id: refIcon
                anchors.centerIn: parent; text: "󰑐"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
                RotationAnimator on rotation {
                    running: rowlay.busy
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 900
                }
            }
            MouseArea {
                id: refMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rowlay.refresh()
            }
        }
    }

    component Row1: Rectangle {
        id: row1id

        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool highlight: false
        signal activated()
        signal menuRequested(real mx, real my)

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: 12
        color: rowMa.containsMouse ? view.sys.colHover
             : (highlight ? Pal.a(0.06) : "transparent")
        Behavior on color { ColorAnimation { duration: 130 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            spacing: 10
            Text {
                text: row1id.icon
                color: row1id.highlight ? view.sys.colOn : view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 15 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: row1id.title
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: row1id.highlight }
                }
                Text {
                    text: row1id.sub
                    visible: text.length > 0
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
            Text {
                visible: row1id.highlight
                text: "󰄬"
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
        }
        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    var p = mapToItem(wifiPage, mouse.x, mouse.y);
                    parent.menuRequested(p.x, p.y);
                } else {
                    parent.activated();
                }
            }
        }
    }

    Component {
        id: lanShape
        LanGlyph { width: 13; height: 13 }
    }

    component Num: Item {
        id: num
        property string value: ""
        property real size: 12
        property real gapRatio: 0.22
        property color color: view.sys.colFg

        implicitWidth:  nDots.implicitWidth
        implicitHeight: nDots.implicitHeight

        DotText {
            id: nDots
            value: num.value
            size: num.size
            gapRatio: num.gapRatio
            color: num.color
        }
    }

    component RecordCard: Rectangle {
        id: recCard

        radius: 14
        color: recBodyMa.containsMouse ? Pal.a(0.08) : Pal.a(0.05)
        border.color: view.sys.recActive
                      ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g,
                                view.sys.colCrit.b, 0.45)
                      : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        MouseArea {
            id: recBodyMa
            anchors.fill: parent
            anchors.leftMargin: 52
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.togglePage("record")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 12
            spacing: 11

            Rectangle {
                id: recBtn
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                color: view.sys.recActive ? view.sys.colCrit : Pal.a(0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: recBtnMa.pressed ? 0.9 : (recBtnMa.containsMouse ? 1.07 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(view.sys.recActive ? 0xF04DB : 0xF040A)
                    color: view.sys.recActive
                           ? view.sys.fgOn(view.sys.colCrit) : "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }

                MouseArea {
                    id: recBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.toggleRecord()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: view.sys.tr("Recording")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font {
                        family: view.sys.fontFam; pixelSize: 9
                        capitalization: Font.AllUppercase; letterSpacing: 1.2
                    }
                }

                Num {
                    Layout.alignment: Qt.AlignLeft
                    value: view.sys.recTimeText
                    size: view.sys.dotHSmall + 3
                    color: !view.sys.recActive ? view.sys.colMuted
                         : view.sys.recPaused ? view.sys.colWarn
                                              : view.sys.colFg
                }
            }
        }
    }

    component LoadRow: RowLayout {
        id: lrow
        property string glyph: ""
        property string name: ""
        property int pct: -1
        property int temp: -1

        visible: lrow.pct >= 0
        spacing: 8

        Glyph {
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            glyph: lrow.glyph
            color: view.sys.colMuted
            fontFam: view.sys.fontFam
            size: 12
        }

        Text {
            Layout.preferredWidth: 30
            text: lrow.name
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: 9; letterSpacing: 0.6 }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            Layout.alignment: Qt.AlignVCenter
            radius: 1.5
            color: Pal.a(0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, lrow.pct)) / 100
                height: parent.height
                radius: parent.radius
                color: view.sys.colFg
                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        Item {
            Layout.preferredWidth: pctRuler.implicitWidth
            Layout.preferredHeight: pctRuler.implicitHeight

            Num {
                id: pctRuler
                visible: false
                value: "100%"
                size: view.sys.dotHTiny
            }

            Num {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                value: lrow.pct + "%"
                size: view.sys.dotHTiny
                color: view.sys.colFg
            }
        }

        RowLayout {
            spacing: 3
            visible: lrow.temp >= 0

            Glyph {
                Layout.preferredWidth: 11
                Layout.preferredHeight: 11
                glyph: String.fromCodePoint(0xF0E01)
                color: lrow.temp >= 80 ? view.sys.colCrit : view.sys.colMuted
                fontFam: view.sys.fontFam
                size: 10
            }
            Num {
                Layout.alignment: Qt.AlignVCenter
                value: lrow.temp + "°"
                size: view.sys.dotHTiny
                color: lrow.temp >= 80 ? view.sys.colCrit : view.sys.colMuted
            }
        }
    }

    component LoadCard: Rectangle {
        radius: 14
        color: Pal.a(0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 4

            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF0EE0); name: "CPU"
                pct: view.sys.loadCpu; temp: view.sys.loadTempCpu
            }
            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF035B); name: "RAM"
                pct: view.sys.loadMem
            }
            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF0379); name: "GPU"
                pct: view.sys.loadGpu; temp: view.sys.loadTempGpu
            }
        }
    }

    Item {
        id: stack
        width: parent.width
        implicitHeight: (view.preview || view.sys.page === "main") ? mainPage.implicitHeight
                      : view.sys.page === "wifi" ? wifiPage.implicitHeight
                      : view.sys.page === "netmenu" ? netMenuPage.implicitHeight
                      : view.sys.page === "traymenu" ? trayPage.implicitHeight
                      : view.sys.page === "battery" ? battPage.implicitHeight
                      : btPage.implicitHeight

        GridLayout {
            id: mainPage
            width: parent.width
            columns: 1
            columnSpacing: 0
            rowSpacing: 9
            opacity: (view.preview || view.sys.page === "main") ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            RowLayout {
                objectName: "cc-clock"
                Layout.row: view.ccRow("clock")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: clockMa.containsMouse ? Pal.a(0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 4
                        spacing: 10

                        RowLayout {
                            spacing: 5

                            DotText {
                                id: ccClock
                                Layout.alignment: Qt.AlignVCenter
                                value: view.sys.timeText
                                size: view.sys.dotHBig
                                color: view.sys.colFg
                                opacity: view.sys.clockFlying ? 0 : 1
                                Component.onCompleted: view.sys.ccClockItem = ccClock
                                Component.onDestruction: if (view.sys.ccClockItem === ccClock) view.sys.ccClockItem = null
                            }
                            DotText {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 1
                                visible: !view.sys.cfg.clockSeconds
                                value: view.sys.secText
                                size: view.sys.dotHSmall
                                color: view.sys.colMuted
                            }
                        }
                        ColumnLayout {
                            spacing: -1
                            Text {
                                text: view.sys.dateLong
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }
                            Text {
                                visible: view.sys.cfg.featCalendar
                                text: view.sys.tr("Calendar")
                                color: clockMa.containsMouse ? view.sys.colOn
                                                            : Pal.a(0.28)
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }

                    MouseArea {
                        id: clockMa
                        anchors.fill: parent
                        hoverEnabled: view.sys.cfg.featCalendar
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("cal")
                    }
                }

            }

            RowLayout {
                objectName: "cc-toggles"
                Layout.row: view.ccRow("toggles")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8

                MiniTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                    iconItem: view.sys.wiredOn ? lanShape : null
                    icon: (view.sys.wifiConnecting || (view.sys.wifiConnectingSsid && view.sys.wifiConnectingSsid.length)) ? "󰤩"
                        : view.sys.wifiOn ? (view.sys.wifiQuality > 66 ? "󰤨"
                                           : view.sys.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                    label: view.sys.wiredOn ? view.sys.tr("Wired")
                         : (view.sys.wifiOn && view.sys.wifiSsid.length)
                           ? view.sys.wifiSsid
                         : (view.sys.wifiConnectingSsid && view.sys.wifiConnectingSsid.length)
                           ? view.sys.wifiConnectingSsid : "Wi-Fi"
                    sub: view.sys.wiredOn ? view.sys.wiredName
                       : !view.sys.wifiOn ? view.sys.tr("Off")
                       : (view.sys.wifiSsid.length)
                         ? view.sys.wifiQuality + "%"
                       : (view.sys.wifiConnecting || (view.sys.wifiConnectingSsid && view.sys.wifiConnectingSsid.length))
                         ? view.sys.tr("Connecting…")
                       : view.sys.tr("Not connected")
                    on: view.sys.wiredOn || view.sys.wifiOn
                    onIconClicked: if (!view.sys.wiredOn) view.sys.toggleWifi()
                    onBodyClicked: {
                        if (!view.sys.wifiOn || !view.sys.cfg.featWifi) return;
                        view.sys.openSub("wifi");
                        view.sys.refreshWifiList();
                        view.sys.scanWifi();
                    }
                }

                MiniTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                    icon: view.sys.btOn ? "󰂯" : "󰂲"
                    label: (view.sys.btOn && view.sys.btConnectedName.length)
                           ? view.sys.btConnectedName : "Bluetooth"
                    sub: !view.sys.btOn ? view.sys.tr("Off")
                       : (view.sys.btConnectedName.length
                          ? (view.sys.btConnectedBattery >= 0
                             ? "󰥉 " + view.sys.btConnectedBattery + "%"
                             : view.sys.tr("Connected"))
                          : view.sys.tr("No devices"))
                    on: view.sys.btOn
                    accent: view.sys.colOn
                    onIconClicked: view.sys.toggleBt()
                    onBodyClicked: {
                        if (!view.sys.btOn || !view.sys.cfg.featBluetooth) return;
                        view.sys.openSub("bt");
                        view.sys.scanBt();
                    }
                }

                VolCard {
                    visible: view.sys.cfg.featAudio
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                }
            }

            RowLayout {
                objectName: "cc-sliders"
                Layout.row: view.ccRow("sliders")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8
                visible: (view.sys.brightList || []).length > 0

                Repeater {
                    model: view.sys.brightList

                    BrightCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 56
                        bid:  modelData.id
                        bpct: modelData.pct
                        bname: (view.sys.brightList || []).length > 1 ? modelData.name : ""
                    }
                }
            }

            Rectangle {
                objectName: "cc-media"
                Layout.row: view.ccRow("media")
                Layout.column: 0
                id: mediaCard
                readonly property var p: view.sys.player

                visible: view.sys.mediaActive && view.sys.cfg.featPlayer
                Layout.fillWidth: true
                Layout.preferredHeight: 124
                radius: 16
                color: Pal.a(0.05)
                border.color: view.sys.colLine
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 10
                            color: Pal.a(0.07)

                            RoundImage {
                                id: cardArt
                                anchors.fill: parent
                                source: view.sys.mediaArt
                                radius: 10
                                sourceWidth: 120
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !cardArt.ready
                                text: "󰝚"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 18 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (mediaCard.p) mediaCard.p.togglePlaying()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: mediaCard.p ? mediaCard.p.trackTitle : ""
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: mediaCard.p ? mediaCard.p.trackArtist : ""
                                color: view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }

                        MediaBtn {
                            icon: "󰒮"
                            enabledAction: mediaCard.p ? mediaCard.p.canGoPrevious : false
                            onAct: if (mediaCard.p) mediaCard.p.previous()
                        }
                        MediaBtn {
                            icon: mediaCard.p && mediaCard.p.isPlaying ? "󰏤" : "󰐊"
                            primary: true
                            enabledAction: mediaCard.p ? mediaCard.p.canTogglePlaying : false
                            onAct: if (mediaCard.p) mediaCard.p.togglePlaying()
                        }
                        MediaBtn {
                            icon: "󰒭"
                            enabledAction: mediaCard.p ? mediaCard.p.canGoNext : false
                            onAct: if (mediaCard.p) mediaCard.p.next()
                        }
                    }

                    Item {
                        id: seek
                        readonly property var p: mediaCard.p
                        readonly property real dur: seek.p ? Math.max(0, seek.p.length) : 0
                        readonly property bool usable:
                            seek.p !== null && seek.dur > 0
                            && seek.p.positionSupported && seek.p.canSeek
                        readonly property real frac: seek.dur > 0
                                ? Math.max(0, Math.min(1, seek.pos / seek.dur)) : 0

                        property real pos: 0
                        property bool dragging: false
                        property bool primed: false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        visible: seek.p !== null
                        Component.onDestruction: seek.primed = false

                        Behavior on pos {
                            enabled: seek.primed && !seek.dragging
                            NumberAnimation { duration: 520; easing.type: Easing.Linear }
                        }
                        Timer {
                            interval: 500
                            repeat: true
                            running: seek.visible && seek.p !== null
                            triggeredOnStart: true
                            onTriggered: {
                                if (seek.p === null) return;
                                seek.p.positionChanged();
                                if (seek.dragging) return;
                                seek.pos = seek.p.position;
                                seek.primed = true;
                            }
                        }
                        Connections {
                            target: mediaCard.p
                            ignoreUnknownSignals: true
                            function onTrackTitleChanged() {
                                seek.dragging = false;
                                seek.primed = false;
                                seek.pos = 0;
                            }
                        }

                        function fracOf(x) {
                            return Math.max(0, Math.min(1, x / Math.max(1, seek.width)));
                        }

                        WaveBars {
                            id: barsRest
                            anchors.fill: parent
                            barCount: 46
                            gap: 3
                            barColor: Pal.a(0.22)
                            active: seek.p ? seek.p.isPlaying : false
                        }

                        Item {
                            width: seek.width * seek.frac
                            height: seek.height
                            clip: true
                            WaveBars {
                                width: seek.width
                                height: seek.height
                                barCount: 46
                                gap: 3
                                barColor: view.sys.colOn
                                active: seek.p ? seek.p.isPlaying : false
                            }
                        }

                        Rectangle {
                            x: seek.width * seek.frac - width / 2
                            width: seekMa.pressed ? 3 : 2
                            height: parent.height
                            radius: 1.5
                            color: "#ffffff"
                            opacity: !seek.usable ? 0
                                   : (seekMa.containsMouse || seekMa.pressed) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: seekMa
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            preventStealing: true
                            enabled: seek.usable
                            cursorShape: seek.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: mouse => {
                                seek.dragging = true;
                                seek.pos = seek.fracOf(mouse.x) * seek.dur;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                seek.pos = seek.fracOf(mouse.x) * seek.dur;
                            }
                            onReleased: mouse => {
                                if (seek.usable) seek.p.position = seek.pos;
                                seek.dragging = false;
                            }
                            onCanceled: seek.dragging = false
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -6
                        visible: seek.visible && seek.dur > 0
                        DotText {
                            value: view.fmtTime(seek.pos)
                            size: view.sys.dotHSmall
                            color: view.sys.colMuted
                        }
                        Item { Layout.fillWidth: true }
                        DotText {
                            value: view.fmtTime(seek.dur)
                            size: view.sys.dotHSmall
                            color: Pal.a(0.28)
                        }
                    }
                }
            }

            RowLayout {
                id: powerRow
                objectName: "cc-power"
                Layout.row: view.ccRow("power")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8

                readonly property int tileH: 76

                RecordCard {
                    visible: view.sys.cfg.featRecord
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: powerRow.tileH
                }

                MiniTile {
                    visible: view.sys.showBattery || view.sys.showPowerProfiles
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: powerRow.tileH
                    icon: view.sys.batteryPresent ? view.sys.batteryLevelIcon
                                                  : String.fromCodePoint(0xF0241)
                    label: view.sys.batteryPresent
                           ? view.sys.batteryPct + "%" : view.sys.tr("Battery")
                    sub: view.sys.batteryCharging ? view.sys.tr("Charging")
                       : view.sys.acOnline ? view.sys.tr("On AC")
                                           : view.sys.profileLabel
                    on: view.sys.batteryCharging || view.sys.acOnline
                    wave: view.sys.batteryCharging
                    waveLevel: view.sys.batteryPct / 100
                    accent: view.sys.batteryPct <= 15 && !view.sys.acOnline
                            ? view.sys.colCrit : view.sys.colOk
                    onIconClicked: view.sys.openSub("battery")
                    onBodyClicked: view.sys.openSub("battery")
                }

                LoadCard {
                    visible: !view.sys.batteryPresent
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1.35
                    Layout.preferredHeight: powerRow.tileH
                }
            }

            RowLayout {
                objectName: "cc-quick"
                Layout.row: view.ccRow("quick")
                Layout.column: 0
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: awakeRow
                readonly property color tint: view.sys.colOn

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: view.sys.keepAwake
                       ? Qt.rgba(awakeRow.tint.r, awakeRow.tint.g, awakeRow.tint.b, 0.16)
                       : (awakeMa.containsMouse ? Pal.a(0.10) : Pal.a(0.05))
                border.color: view.sys.keepAwake
                              ? Qt.rgba(awakeRow.tint.r, awakeRow.tint.g, awakeRow.tint.b, 0.40)
                              : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    spacing: 11

                    Glyph {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        glyph: String.fromCodePoint(view.sys.keepAwake ? 0xF0176 : 0xF0177)
                        color: view.sys.keepAwake ? awakeRow.tint : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize + 2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Coffee mode"
                        color: view.sys.keepAwake ? view.sys.colFg : view.sys.colMuted
                        font {
                            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2
                            bold: view.sys.keepAwake
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 21
                        radius: 11
                        color: view.sys.keepAwake ? awakeRow.tint : Pal.a(0.14)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Rectangle {
                            width: 17; height: 17; radius: 9
                            y: 2
                            x: view.sys.keepAwake ? parent.width - width - 2 : 2
                            color: view.sys.keepAwake
                                   ? view.sys.fgOn(awakeRow.tint) : "#ffffff"
                            Behavior on x {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                MouseArea {
                    id: awakeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.keepAwake = !view.sys.keepAwake
                }
            }

            IconBtn {
                glyph: String.fromCodePoint(0xF0425)
                tip: view.sys.tr("Power")
                activeColor: view.sys.colCrit
                onAct: view.sys.togglePage("power")
            }

            IconBtn {
                visible: view.sys.cfg.featNotifications
                glyph: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF009A)
                tip: view.sys.dnd ? view.sys.tr("Do not disturb") : view.sys.tr("Notifications")
                badge: view.sys.notifications.count
                onAct: view.sys.togglePage("notif")
            }

            IconBtn {
                glyph: String.fromCodePoint(0xF0493)
                tip: view.sys.tr("Settings")
                onAct: view.sys.togglePage("settings")
            }
            }

            RowLayout {
                objectName: "cc-tray"
                Layout.row: view.ccRow("tray")
                Layout.column: 0
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8
                visible: view.sys.trayItems.values.length > 0

                Text {
                    text: view.sys.tr("Tray")
                    color: view.sys.colMuted
                    font {
                        family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                        bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }

                Repeater {
                    model: view.sys.trayItems

                    Rectangle {
                        id: trayBtn
                        required property var modelData

                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        z: trayMa.containsMouse ? 10 : 0
                        radius: 10
                        color: trayMa.containsMouse ? Pal.a(0.13) : Pal.a(0.05)
                        border.color: view.sys.colLine
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: trayMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 7
                            source: String(trayBtn.modelData.icon || "")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    if (!trayBtn.modelData.hasMenu) return;
                                    view.sys.trayMenuItem = trayBtn.modelData;
                                    view.sys.page = "traymenu";
                                    view.sys.holdOpen = true;
                                    return;
                                }
                                if (mouse.button === Qt.MiddleButton)
                                    trayBtn.modelData.secondaryActivate();
                                else
                                    trayBtn.modelData.activate();
                                view.sys.collapse();
                            }
                        }

                        Rectangle {
                            id: tip
                            readonly property string label:
                                String(trayBtn.modelData.tooltipTitle
                                       || trayBtn.modelData.title || "")

                            visible: opacity > 0.01
                            opacity: (trayMa.containsMouse && label.length) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            width: tipText.implicitWidth + 20
                            height: 26
                            radius: 13
                            x: (parent.width - width) / 2
                            y: -height - 8
                            color: Qt.rgba(0.04, 0.04, 0.05, 0.96)
                            border.color: view.sys.colLine
                            border.width: 1

                            scale: trayMa.containsMouse ? 1 : 0.92
                            transformOrigin: Item.Bottom
                            Behavior on scale {
                                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                            }

                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: tip.label
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        ColumnLayout {
            id: battPage
            width: parent.width
            spacing: 8
            opacity: view.sys.page === "battery" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Battery")
                onBack: view.sys.page = "main"
            }

            Rectangle {
                id: reg

                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 14
                color: Pal.a(0.05)
                border.color: view.sys.colLine
                border.width: 1

                readonly property color tint:
                    view.sys.batteryCharging || view.sys.acOnline ? view.sys.colOk
                  : view.sys.batteryPct <= 15 ? view.sys.colCrit
                  : view.sys.colFg

                ChargeWave {
                    anchors.fill: parent
                    radius: parent.radius
                    tint: view.sys.colOk
                    level: view.sys.batteryPct / 100
                    running: view.sys.batteryCharging
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Glyph {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        glyph: view.sys.batteryLevelIcon
                        color: reg.tint
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize + 3
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: view.sys.batteryPct + "%"
                            color: reg.tint
                            font { family: view.sys.fontFam; pixelSize: 18; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: view.sys.batteryCharging
                                  ? view.sys.tr("Charging")
                                  : view.sys.acOnline ? view.sys.tr("On AC")
                                                      : view.sys.profileLabel
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: 15
                        visible: view.sys.batteryCharging || view.sys.acOnline
                        color: Qt.rgba(view.sys.colOk.r, view.sys.colOk.g,
                                       view.sys.colOk.b, 0.18)

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(
                                      view.sys.batteryCharging ? 0xF0241 : 0xF06A5)
                            color: view.sys.colOk
                            font { family: view.sys.fontFam; pixelSize: 15 }
                            SequentialAnimation on opacity {
                                running: view.sys.batteryCharging
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 750; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                            }
                            onVisibleChanged: if (!visible) opacity = 1
                        }
                    }
                }
            }

            RowLayout {
                visible: view.sys.showPowerProfiles
                Layout.fillWidth: true
                spacing: 8

                PowerSeg {
                    icon: "󰾆"
                    label: view.sys.tr("Power saver")
                    profile: "power-saver"
                    accent: view.sys.colOk
                }
                PowerSeg {
                    icon: "󰾅"
                    label: view.sys.tr("Balanced")
                    profile: "balanced"
                    accent: view.sys.colOn
                }
                PowerSeg {
                    icon: "󰓅"
                    label: view.sys.tr("Performance")
                    profile: "performance"
                    accent: view.sys.colWarn
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: view.sys.batteryPresent

                BattStat {
                    label: view.sys.tr("Capacity")
                    value: view.sys.batteryCapacity > 0
                           ? view.sys.batteryCapacity.toFixed(1) + " Wh" : "—"
                }
                BattStat {
                    label: view.sys.tr("Health")
                    value: view.sys.batteryHealth > 0
                           ? view.sys.batteryHealth + "%" : "—"
                }
                BattStat {
                    label: view.sys.batteryCharging ? "󰐥" : "󰚥"
                    value: Math.abs(view.sys.batteryRate) > 0.05
                           ? Math.abs(view.sys.batteryRate).toFixed(1) + " W" : "—"
                }
            }
            BatteryDetails {
                Layout.fillWidth: true
                sys: view.sys
                visible: view.sys.batteryPresent
            }
        }

        ColumnLayout {
            id: wifiPage
            width: parent.width
            spacing: 7

            property string menuSsid: ""
            property bool menuConnected: false
            property bool menuKnown: false

            opacity: view.sys.page === "wifi" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Wi-Fi networks")
                busy: view.sys.wifiBusy
                onBack: { view.sys.page = "main"; wifiPage.passwordFor = ""; }
                onRefresh: view.sys.scanWifi()
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiSsid.length > 0 && wifiInfo.info.length > 0
                text: wifiInfo.info
                color: view.sys.colMuted
                elide: Text.ElideRight
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
            Process {
                id: wifiInfo
                property string info: ""
                running: wifiPage.visible && view.sys.wifiSsid.length > 0
                command: ["sh", "-c", "d=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2==\"wifi\" && $3==\"connected\" {print $1; exit}'); [ -n \"$d\" ] || exit 0; ip=$(nmcli -g IP4.ADDRESS dev show \"$d\" | head -1 | cut -d/ -f1); l=$(iw dev \"$d\" link 2>/dev/null); f=$(printf '%s' \"$l\" | awk '/freq:/{print $2; exit}'); r=$(printf '%s' \"$l\" | awk '/tx bitrate:/{print $3; exit}'); b=''; [ -n \"$f\" ] && { [ ${f%%.*} -ge 5900 ] && b='6 GHz' || { [ ${f%%.*} -ge 4900 ] && b='5 GHz' || b='2.4 GHz'; }; }; printf '%s' \"${ip:+IP $ip}${b:+  ·  $b}${r:+  ·  ${r%%.*} Mb/s}\""]
                stdout: StdioCollector { onStreamFinished: wifiInfo.info = text.trim() }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: 6
                ActionBtn {
                    glyph: String.fromCodePoint(0xF001D)
                    label: view.sys.tr("Airplane")
                    on: wifiPage.airplane
                    onAct: {
                        airplaneSet.command = ["sh", "-c", wifiPage.airplane ? "rfkill unblock all" : "rfkill block all"];
                        airplaneSet.running = true;
                    }
                }
                ActionBtn {
                    glyph: String.fromCodePoint(0xF0415)
                    label: view.sys.tr("Hidden network…")
                    onAct: view.launch(["nm-connection-editor", "--create", "--type=802-11-wireless"])
                }
                ActionBtn {
                    glyph: String.fromCodePoint(0xF0493)
                    label: view.sys.tr("Network settings…")
                    onAct: view.launch(["nm-connection-editor"])
                }
            }
            property bool airplane: false
            Process {
                id: airplaneGet
                running: wifiPage.visible
                command: ["sh", "-c", "rfkill -n -o SOFT list | grep -qv '^blocked$' && echo off || echo on"]
                stdout: StdioCollector { onStreamFinished: wifiPage.airplane = text.trim() === "on" }
            }
            Process {
                id: airplaneSet
                onExited: { airplaneGet.running = false; airplaneGet.running = true; view.sys.refreshWifiStatus(); }
            }

            property string passwordFor: ""
            property string passwordSecurity: "psk"

            TextField {
                id: userField
                Layout.fillWidth: true
                visible: wifiPage.passwordFor.length > 0 && wifiPage.passwordSecurity === "eap"
                placeholderText: view.sys.tr("Username")
                color: view.sys.colFg
                placeholderTextColor: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 12 }
                onAccepted: pwField.forceActiveFocus()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                visible: wifiPage.passwordFor.length > 0
                radius: 12
                color: Pal.a(0.06)
                border.color: view.sys.colLine
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 7
                    spacing: 8

                    Text {
                        text: "󰌾"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 14 }
                    }
                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        placeholderText: view.sys.tr("Password for \u00ab") + wifiPage.passwordFor + "»"
                        echoMode: TextInput.Password
                        color: view.sys.colFg
                        placeholderTextColor: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                        background: null
                        onAccepted: connectBtn.go()
                    }
                    Rectangle {
                        id: connectBtn
                        function go() {
                            if (!pwField.text.length || (wifiPage.passwordSecurity === "eap" && !userField.text.length)) return;
                            view.sys.connectWifi(wifiPage.passwordFor, pwField.text, userField.text, wifiPage.passwordSecurity);
                            wifiPage.passwordFor = "";
                            pwField.text = "";
                            userField.text = "";
                            view.sys.holdOpen = false;
                        }
                        Layout.preferredWidth: 34; Layout.preferredHeight: 32
                        radius: 10
                        color: pwField.text.length && (wifiPage.passwordSecurity !== "eap" || userField.text.length)
                               ? view.sys.colOn : Pal.a(0.10)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF0054)
                            color: view.sys.fgOn(parent.color)
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectBtn.go()
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiError.length > 0
                text: view.sys.wifiError
                color: view.sys.colCrit
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.wifiNetworks
                    Row1 {
                        required property var model
                        readonly property bool isConnecting: view.sys.wifiConnectingSsid.length > 0 && model.ssid === view.sys.wifiConnectingSsid
                        icon: isConnecting ? "󰤩" : (model.quality > 66 ? "󰤨" : model.quality > 33 ? "󰤥" : "󰤟")
                        title: model.ssid
                        sub: isConnecting ? view.sys.tr("Connecting…")
                             : ((model.security === "open" ? view.sys.tr("Open") : model.security === "eap" ? view.sys.tr("Enterprise") : view.sys.tr("Secured"))
                              + " · " + model.quality + "%"
                              + (model.known ? view.sys.tr(" · saved") : ""))
                        highlight: model.connected || isConnecting
                        onActivated: {
                            if (model.connected || isConnecting) return;
                            if (model.security === "open" || model.known) {
                                view.sys.connectWifi(model.ssid, "");
                            } else {
                                wifiPage.passwordFor = model.ssid;
                                wifiPage.passwordSecurity = model.security;
                                view.sys.holdOpen = true;
                                pwFocus.restart();
                            }
                        }
                        onMenuRequested: (mx, my) => {
                            if (!model.connected && !model.known) return;
                            wifiPage.menuSsid = model.ssid;
                            wifiPage.menuConnected = model.connected;
                            wifiPage.menuKnown = model.known;
                            view.sys.page = "netmenu";
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiNetworks.count === 0
                text: view.sys.wifiBusy ? view.sys.tr("Scanning networks…") : view.sys.tr("No networks found")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            Timer { id: pwFocus; interval: 80; onTriggered: (wifiPage.passwordSecurity === "eap" ? userField : pwField).forceActiveFocus() }

                }

        ColumnLayout {
            id: netMenuPage
            width: parent.width
            spacing: 3
            opacity: view.sys.page === "netmenu" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: wifiPage.menuSsid.length ? wifiPage.menuSsid : view.sys.tr("Network")
                busy: view.sys.wifiBusy
                onBack: view.sys.page = "wifi"
                onRefresh: {}
            }

            Row1 {
                visible: wifiPage.menuConnected
                icon: "󰖪"
                title: view.sys.tr("Disconnect")
                sub: view.sys.tr("Drops the link, keeps the network saved")
                onActivated: {
                    view.sys.disconnectWifi();
                    view.sys.page = "wifi";
                }
            }

            Row1 {
                visible: wifiPage.menuKnown
                icon: "󰅖"
                title: view.sys.tr("Forget network")
                sub: view.sys.tr("Stop connecting automatically")
                onActivated: {
                    view.sys.forgetWifi(wifiPage.menuSsid);
                    view.sys.page = "wifi";
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: !wifiPage.menuConnected && !wifiPage.menuKnown
                text: view.sys.tr("Nothing is saved for this network.")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        ColumnLayout {
            id: trayPage
            width: parent.width
            spacing: 3
            opacity: view.sys.page === "traymenu" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            property var chain: []
            readonly property var rootHandle:
                view.sys.trayMenuItem ? view.sys.trayMenuItem.menu : null
            readonly property var handle:
                chain.length > 0 ? chain[chain.length - 1] : rootHandle

            onRootHandleChanged: if (chain.length > 0) chain = []

            QsMenuOpener {
                id: menuOpener
                menu: trayPage.handle
            }

            Header {
                title: view.sys.trayMenuItem
                       ? String(view.sys.trayMenuItem.tooltipTitle
                                || view.sys.trayMenuItem.title || view.sys.tr("Menu"))
                       : view.sys.tr("Menu")
                busy: false
                onBack: {
                    if (trayPage.chain.length > 0) {
                        var c = trayPage.chain.slice();
                        c.pop();
                        trayPage.chain = c;
                    } else {
                        view.sys.page = "main";
                        view.sys.trayMenuItem = null;
                    }
                }
                onRefresh: {}
            }

            Repeater {
                model: menuOpener.children

                Item {
                    id: entry
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.isSeparator ? 9 : 34

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        height: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.sys.colLine
                    }

                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: 10
                        color: entryMa.containsMouse && entry.modelData.enabled
                               ? view.sys.colHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 9

                            Text {
                                visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                text: entry.modelData.checkState === Qt.Checked
                                      ? "󰄬" : "󰝦"
                                color: entry.modelData.checkState === Qt.Checked
                                       ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            Image {
                                visible: String(entry.modelData.icon || "").length > 0
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: String(entry.modelData.icon || "")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(entry.modelData.text || "")
                                color: entry.modelData.enabled
                                       ? view.sys.colFg : view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            Text {
                                visible: entry.modelData.hasChildren
                                text: String.fromCodePoint(0xF0142)
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }

                        MouseArea {
                            id: entryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    var c = trayPage.chain.slice();
                                    c.push(entry.modelData);
                                    trayPage.chain = c;
                                    return;
                                }
                                entry.modelData.triggered();
                                view.sys.collapse();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !menuOpener.children || menuOpener.children.values.length === 0
                text: view.sys.tr("Menu is empty")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        ColumnLayout {
            id: btPage
            width: parent.width
            spacing: 7
            opacity: view.sys.page === "bt" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Bluetooth")
                busy: view.sys.btAdapter ? view.sys.btAdapter.discovering : false
                onBack: view.sys.page = "main"
                onRefresh: view.sys.scanBt()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.btList
                    Row1 {
                        id: row1
                        required property var modelData
                        icon: (modelData.icon === "audio-headset" || modelData.icon === "audio-headphones") ? "󱡏"
                            : modelData.icon === "input-mouse" ? "󰦋"
                            : modelData.icon === "input-keyboard" ? "󰌌"
                            : (modelData.icon === "audio-speakers" || modelData.icon === "audio-speaker") ? "󰓃"
                            : modelData.icon === "input-gaming" ? "󰊴"
                            : (modelData.icon === "phone" || modelData.icon === "smartphone") ? "󰄞"
                            : modelData.icon === "watch" ? "󰖄" : "󰂯"
                        title: modelData.name || modelData.address
                        sub: modelData.pairing ? view.sys.tr("Pairing…")
                           : modelData.state === BluetoothDeviceState.Connecting ? view.sys.tr("Connecting…")
                           : modelData.connected ? view.sys.tr("Connected")
                           : (modelData.paired || modelData.bonded ? view.sys.tr("Paired") : view.sys.tr("Available"))
                             + (modelData.batteryAvailable
                                ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                        highlight: modelData.connected || modelData.pairing
                                   || modelData.state === BluetoothDeviceState.Connecting
                        onActivated: {
                            if (modelData.connected) { modelData.disconnect(); return; }
                            modelData.trusted = true;
                            if (modelData.paired || modelData.bonded) modelData.connect();
                            else modelData.pair();
                        }
                        property var dev: modelData
                        Connections {
                            target: row1.dev
                            function onPairedChanged() {
                                if (row1.dev.paired && !row1.dev.connected) row1.dev.connect();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.btList.length === 0
                text: (view.sys.btAdapter && view.sys.btAdapter.discovering)
                      ? view.sys.tr("Scanning devices…") : view.sys.tr("No devices found")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                ActionBtn {
                    glyph: String.fromCodePoint(0xF0552)
                    label: view.sys.tr("Send files…")
                    onAct: view.launch(["blueman-sendto"])
                }
                ActionBtn {
                    glyph: String.fromCodePoint(0xF00AF)
                    label: view.sys.tr("Adapter…")
                    onAct: view.launch(["blueman-adapters"])
                }
                ActionBtn {
                    glyph: String.fromCodePoint(0xF0493)
                    label: view.sys.tr("Bluetooth settings…")
                    onAct: view.launch(["blueman-manager"])
                }
            }
        }
    }

}
