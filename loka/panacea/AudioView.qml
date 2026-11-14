pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight
    focus: true
    Component.onCompleted: { forceActiveFocus(); view.refreshPorts(); }
    function goBack() { view.sys.page = "main"; return true; }
    Keys.onEscapePressed: view.goBack()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var sourceAudio: source ? source.audio : null

    readonly property var allNodes: Pipewire.nodes ? Pipewire.nodes.values : []

    property var unavailable: []
    function refreshPorts() { pPorts.running = false; pPorts.running = true; }
    Process {
        id: pPorts
        command: ["sh", "-c", "for k in sinks sources; do pactl -f json list $k 2>/dev/null | jq -r '.[] | select(.active_port as $a | .ports | map(select(.name == $a))[0].availability == \"not available\") | .name'; done"]
        stdout: StdioCollector {
            onStreamFinished: view.unavailable = text.split("\n").filter(s => s.length)
        }
    }
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { portDebounce.restart(); }
    }
    Timer { id: portDebounce; interval: 400; onTriggered: view.refreshPorts() }

    function usable(n) {
        if (!n) return false;
        var name = String(n.name || "");
        return view.unavailable.indexOf(name) < 0 || n === view.sink || n === view.source;
    }

    readonly property var outputs: view.allNodes.filter(n => n && n.audio && n.isSink && !n.isStream && view.usable(n))
    readonly property var inputs: view.allNodes.filter(n => n && n.audio && !n.isSink && !n.isStream
                                                         && !String(n.name || "").endsWith(".monitor") && view.usable(n))
    readonly property var streams: view.allNodes.filter(n => {
        if (!n || !n.audio || !n.isStream || !n.isSink) return false;
        var a = String((n.properties && n.properties["application.name"]) || n.name || "").toLowerCase();
        return a.indexOf("cava") < 0 && a.indexOf("quickshell") < 0;
    })

    PwObjectTracker { objects: view.streams.concat(view.outputs).concat(view.inputs) }

    function devName(n) {
        var s = String(n.nickname || n.description || n.name || "");
        return s.replace(/^.*cAVS\s+/, "");
    }
    function volIcon(a) {
        if (!a || a.muted) return String.fromCodePoint(0xF075F);
        return a.volume < 0.34 ? String.fromCodePoint(0xF057F)
             : a.volume < 0.67 ? String.fromCodePoint(0xF0580) : String.fromCodePoint(0xF057E);
    }
    function micIcon(a) { return (!a || a.muted) ? String.fromCodePoint(0xF036D) : String.fromCodePoint(0xF036C); }
    function appGlyph(n) {
        var p = n.properties || {};
        var s = (String(p["application.name"] || "") + " " + String(p["application.process.binary"] || "")).toLowerCase();
        if (s.indexOf("chrom") >= 0 || s.indexOf("thorium") >= 0) return String.fromCodePoint(0xF268);
        if (s.indexOf("firefox") >= 0) return String.fromCodePoint(0xF269);
        if (s.indexOf("spotify") >= 0) return String.fromCodePoint(0xF1BC);
        if (s.indexOf("discord") >= 0) return String.fromCodePoint(0xF392);
        if (s.indexOf("vlc") >= 0 || s.indexOf("mpv") >= 0) return String.fromCodePoint(0xF144);
        if (s.indexOf("limusic") >= 0) return String.fromCodePoint(0xF075A);
        return String.fromCodePoint(0xF028);
    }

    component Heading: Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        color: view.sys.colMuted
        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true; capitalization: Font.AllUppercase; letterSpacing: 1 }
    }

    component VolSlider: Item {
        id: vs
        property var audio: null
        property real maxVol: 1.0
        property int knobSize: 18
        property int track: 6
        Layout.fillWidth: true
        Layout.preferredHeight: knobSize + 8
        readonly property real pos: vs.audio ? Math.max(0, Math.min(1, vs.audio.volume / vs.maxVol)) : 0
        readonly property real usableW: width - knob.width
        function setFromX(x) {
            if (!vs.audio) return;
            var r = Math.max(0, Math.min(1, (x - knob.width / 2) / Math.max(1, vs.usableW)));
            vs.audio.muted = false;
            vs.audio.volume = Math.round(r * vs.maxVol * 100) / 100;
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: knob.width / 2
            width: vs.usableW
            height: vs.track
            radius: vs.track / 2
            color: Pal.a(0.12)
            Rectangle {
                width: parent.width * vs.pos
                height: parent.height
                radius: parent.radius
                color: vs.audio && vs.audio.muted ? view.sys.colMuted : view.sys.colOn
            }
            Rectangle {
                visible: vs.maxVol > 1
                x: parent.width / vs.maxVol - 1
                width: 2; height: parent.height + 6
                anchors.verticalCenter: parent.verticalCenter
                color: Pal.a(0.35)
            }
        }
        Rectangle {
            id: knob
            width: vs.knobSize; height: vs.knobSize; radius: vs.knobSize / 2
            anchors.verticalCenter: parent.verticalCenter
            x: vs.pos * vs.usableW
            color: "#ffffff"
            border.color: view.sys.colBg
            border.width: 2
            scale: ma.pressed ? 1.2 : (ma.containsMouse ? 1.08 : 1.0)
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: m => vs.setFromX(m.x)
            onPositionChanged: m => { if (pressed) vs.setFromX(m.x); }
            onWheel: w => {
                if (!vs.audio) return;
                vs.audio.muted = false;
                vs.audio.volume = Math.max(0, Math.min(vs.maxVol, vs.audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)));
            }
        }
    }

    component LevelRow: RowLayout {
        id: lr
        property var audio: null
        property string glyph: ""
        Layout.fillWidth: true
        spacing: 12
        Text {
            Layout.preferredWidth: 26
            horizontalAlignment: Text.AlignHCenter
            text: lr.glyph
            color: lr.audio && lr.audio.muted ? view.sys.colMuted : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: if (lr.audio) lr.audio.muted = !lr.audio.muted
            }
        }
        VolSlider { audio: lr.audio }
        Text {
            Layout.preferredWidth: 46
            horizontalAlignment: Text.AlignRight
            text: !lr.audio ? "—" : lr.audio.muted ? view.sys.tr("Muted") : Math.round(lr.audio.volume * 100) + "%"
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }

    component DeviceRow: Rectangle {
        id: dr
        required property var modelData
        property bool isInput: false
        readonly property bool active: dr.isInput ? view.source === dr.modelData : view.sink === dr.modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 11
        color: dr.active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                         : (dma.containsMouse ? Pal.a(0.10) : Pal.a(0.05))
        border.color: dr.active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10
            Text {
                text: dr.isInput ? String.fromCodePoint(0xF036C) : String.fromCodePoint(0xF04C3)
                color: dr.active ? view.sys.colOn : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
            }
            Text {
                Layout.fillWidth: true
                text: view.devName(dr.modelData)
                color: dr.active ? view.sys.colFg : view.sys.colMuted
                elide: Text.ElideRight
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: dr.active }
            }
            Text {
                visible: dr.active
                text: String.fromCodePoint(0xF012C)
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
            }
        }
        MouseArea {
            id: dma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (dr.isInput) Pipewire.preferredDefaultAudioSource = dr.modelData;
                else Pipewire.preferredDefaultAudioSink = dr.modelData;
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 10
                color: backMa.containsMouse ? Pal.a(0.13) : Pal.a(0.06)
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF004D)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.goBack()
                }
            }
            Text {
                Layout.fillWidth: true
                text: view.sys.tr("Sound")
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1; bold: true }
            }
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: mixTxt.implicitWidth + 22
                radius: 10
                color: mixMa.containsMouse ? Pal.a(0.13) : Pal.a(0.06)
                Text {
                    id: mixTxt
                    anchors.centerIn: parent
                    text: view.sys.tr("Sound settings…")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
                MouseArea {
                    id: mixMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Quickshell.execDetached(["pavucontrol"]); view.sys.collapse(); }
                }
            }
        }

        Heading { text: view.sys.tr("Output") }
        LevelRow { audio: view.sinkAudio; glyph: view.volIcon(view.sinkAudio) }
        Repeater {
            model: view.outputs.length > 1 ? view.outputs : []
            DeviceRow {}
        }

        Heading { text: view.sys.tr("Input") }
        LevelRow { audio: view.sourceAudio; glyph: view.micIcon(view.sourceAudio) }
        Repeater {
            model: view.inputs.length > 1 ? view.inputs : []
            DeviceRow { isInput: true }
        }

        Heading { text: view.sys.tr("Applications"); visible: view.streams.length > 0 }
        Repeater {
            model: view.streams
            Rectangle {
                id: app
                required property var modelData
                readonly property var audio: app.modelData.audio
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 12
                color: Pal.a(0.05)
                border.color: view.sys.colLine
                border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: view.appGlyph(app.modelData)
                            color: app.audio && app.audio.muted ? view.sys.colMuted : view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (app.audio) app.audio.muted = !app.audio.muted
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            readonly property var p: app.modelData.properties || {}
                            text: String(p["application.name"] || app.modelData.name || "")
                                  + (p["media.name"] && p["media.name"] !== "Playback" ? "  ·  " + p["media.name"] : "")
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                        }
                        Text {
                            text: !app.audio ? "" : app.audio.muted ? view.sys.tr("Muted") : Math.round(app.audio.volume * 100) + "%"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }
                    }
                    VolSlider { audio: app.audio; maxVol: 1.5; knobSize: 14; track: 4 }
                }
            }
        }
    }
}
