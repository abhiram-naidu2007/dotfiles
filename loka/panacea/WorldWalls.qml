pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Themes.js" as Themes

PanelWindow {
    id: win
    required property var sys
    property bool open: false
    property string world: ""

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: win.open
    visible: win.open || stage.opacity > 0.01

    readonly property var worlds: Themes.worlds()
    readonly property var meta: Themes.of(win.world)
    readonly property string bodyFont: win.meta.fonts ? win.meta.fonts[1] : "Inter"
    readonly property string displayFont: win.meta.fonts ? win.meta.fonts[2] : "Inter"

    function show(name) {
        win.world = name || win.sys.cfg.themeId;
        win.open = true;
        win.load();
    }
    function hide() { win.open = false; }

    ListModel { id: walls }
    property string pendingCurrent: ""

    function load() {
        walls.clear();
        pCur.command = ["sh", "-c", "cat \"$HOME/.local/state/rice/world-$1\" 2>/dev/null", "_", win.world];
        pCur.running = true;
    }
    Process {
        id: pCur
        stdout: StdioCollector {
            onStreamFinished: {
                win.pendingCurrent = text.trim();
                pList.command = ["rice", "world-walls", win.world];
                pList.running = true;
            }
        }
    }
    Process {
        id: pList
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = text.split("\n"), at = 0;
                walls.clear();
                for (var i = 0; i < rows.length; i++) {
                    var p = rows[i].split("|");
                    if (p.length < 3) continue;
                    if (p[0] === win.pendingCurrent) at = walls.count;
                    walls.append({ path: p[0], kind: p[1], thumb: p[2], name: p[0].split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]/g, " ") });
                }
                reel.currentIndex = at;
                reel.positionViewAtIndex(at, ListView.Center);
            }
        }
    }

    function stepWorld(d) {
        var i = 0;
        for (var k = 0; k < win.worlds.length; k++) if (win.worlds[k].id === win.world) i = k;
        win.world = win.worlds[(i + d + win.worlds.length) % win.worlds.length].id;
        win.load();
    }
    function apply() {
        if (reel.currentIndex < 0 || reel.currentIndex >= walls.count) return;
        var w = walls.get(reel.currentIndex);
        win.sys.applyWorldWall(win.world, w.path);
        win.hide();
    }

    Item {
        id: stage
        anchors.fill: parent
        focus: true
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? 200 : 110; easing.type: win.open ? Easing.OutCubic : Easing.InCubic } }
        FocusGrabber { target: win.open ? stage : null; running: win.open }

        Keys.onEscapePressed: win.hide()
        Keys.onLeftPressed: reel.decrementCurrentIndex()
        Keys.onRightPressed: reel.incrementCurrentIndex()
        Keys.onUpPressed: win.stepWorld(-1)
        Keys.onDownPressed: win.stepWorld(1)
        Keys.onTabPressed: win.stepWorld(1)
        Keys.onBacktabPressed: win.stepWorld(-1)
        Keys.onReturnPressed: win.apply()
        Keys.onEnterPressed: win.apply()
        Keys.onPressed: e => {
            if (e.key === Qt.Key_H) { reel.decrementCurrentIndex(); e.accepted = true; }
            else if (e.key === Qt.Key_L) { reel.incrementCurrentIndex(); e.accepted = true; }
            else if (e.key === Qt.Key_K) { win.stepWorld(-1); e.accepted = true; }
            else if (e.key === Qt.Key_J) { win.stepWorld(1); e.accepted = true; }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(win.meta.bg, 0.55)
            Behavior on color { ColorAnimation { duration: 260 } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: win.hide()
            onWheel: w => {
                if (w.angleDelta.y > 0 || w.angleDelta.x > 0) reel.decrementCurrentIndex();
                else reel.incrementCurrentIndex();
            }
        }

        Row {
            id: tabs
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - 290
            spacing: 8
            Repeater {
                model: win.worlds
                Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool on: modelData.id === win.world
                    width: tabTxt.implicitWidth + 36
                    height: 40
                    radius: 20
                    color: on ? modelData.on : Qt.alpha(modelData.bg, 0.85)
                    border.width: on ? 0 : 1
                    border.color: Qt.alpha(modelData.fg, 0.18)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Text {
                        id: tabTxt
                        anchors.centerIn: parent
                        text: tab.modelData.name
                        color: tab.on ? tab.modelData.bg : tab.modelData.fg
                        font.family: tab.modelData.fonts[2]
                        font.pixelSize: 17
                        font.weight: tab.on ? Font.DemiBold : Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { win.world = tab.modelData.id; win.load(); }
                    }
                }
            }
        }

        ListView {
            id: reel
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 20 }
            height: 480
            orientation: ListView.Horizontal
            model: walls
            property real ih: 360
            property real imgW: 766
            property real slotW: 330
            property real sideBase: 0.56
            spacing: 0
            clip: false
            cacheBuffer: 1200
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - slotW) / 2
            preferredHighlightEnd: (width + slotW) / 2
            highlightMoveDuration: 360
            highlightMoveVelocity: 3000
            snapMode: ListView.SnapToItem
            boundsBehavior: Flickable.StopAtBounds
            interactive: false

            delegate: Item {
                id: slot
                required property int index
                required property string path
                required property string kind
                required property string thumb
                required property string name
                width: reel.slotW
                height: reel.height
                readonly property real d: (x + width / 2 - (reel.contentX + reel.width / 2)) / reel.slotW
                readonly property real ad: Math.abs(d)
                readonly property real sc: ad <= 1
                    ? reel.sideBase + (1 - reel.sideBase) * Math.pow(1 - ad, 1.35)
                    : reel.sideBase * Math.pow(0.86, ad - 1)
                readonly property bool current: slot.path === win.pendingCurrent
                z: Math.round(100 - ad * 10)
                opacity: Math.max(0, Math.min(1, 1.15 - 0.34 * ad))

                Item {
                    id: card
                    anchors.centerIn: parent
                    width: reel.imgW
                    height: reel.ih
                    scale: slot.sc
                    Image {
                        anchors.fill: parent
                        source: "file://" + slot.thumb
                        asynchronous: true
                        cache: true
                        smooth: true
                        sourceSize: Qt.size(reel.imgW, reel.ih)
                    }
                    Image {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("assets/card-outline.png")
                        opacity: slot.ad < 0.5 ? 0.9 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    Rectangle {
                        visible: slot.kind === "video"
                        x: parent.width - width - 30
                        y: 16
                        width: liveTxt.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: win.meta.on
                        Text {
                            id: liveTxt
                            anchors.centerIn: parent
                            text: "LIVE"
                            color: win.meta.bg
                            font.family: win.bodyFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                    }
                    Rectangle {
                        visible: slot.current
                        x: 150
                        y: 16
                        width: nowTxt.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: Qt.alpha(win.meta.bg, 0.85)
                        Text {
                            id: nowTxt
                            anchors.centerIn: parent
                            text: "NOW"
                            color: win.meta.fg
                            font.family: win.bodyFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: slot.ad < 0.5 ? win.apply() : (reel.currentIndex = slot.index)
                    }
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + 250
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: reel.currentIndex >= 0 && reel.currentIndex < walls.count ? walls.get(reel.currentIndex).name : (pList.running ? "…" : "No wallpapers in ~/dotfiles/wallpaper/" + win.world)
                color: win.meta.fg
                font.family: win.displayFont
                font.pixelSize: 20
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "←→ wallpaper    ↑↓ / Tab world    Enter set    Esc close"
                color: Qt.alpha(win.meta.fg, 0.6)
                font.family: win.bodyFont
                font.pixelSize: 12
            }
        }
    }
}
