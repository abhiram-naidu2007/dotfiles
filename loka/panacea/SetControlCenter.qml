pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var sys

    readonly property var blocks: [
        { id: "clock",   name: page.sys.tr("Clock and date") },
        { id: "toggles", name: page.sys.tr("Wi-Fi · Bluetooth") },
        { id: "sliders", name: page.sys.tr("Volume and brightness") },
        { id: "media",   name: page.sys.tr("Now playing") },
        { id: "power",   name: page.sys.tr("Recording and power profile") },
        { id: "quick",   name: page.sys.tr("Stay awake and buttons") },
        { id: "tray",    name: page.sys.tr("System tray") }
    ]
    readonly property var defOrder: page.blocks.map(b => b.id)

    property var order: []
    property bool dirty: false

    function load() {
        var saved = String(page.sys.cfg.ccLayout || "").split(",").filter(x => x.length);
        var out = saved.filter(id => page.defOrder.indexOf(id) >= 0);
        page.defOrder.forEach(id => { if (out.indexOf(id) < 0) out.push(id); });
        page.order = out;
        page.dirty = false;
    }
    function nameOf(id) {
        for (var i = 0; i < page.blocks.length; i++)
            if (page.blocks[i].id === id) return page.blocks[i].name;
        return id;
    }
    function move(from, to) {
        if (to < 0 || to >= page.order.length || from === to) return;
        var a = page.order.slice();
        a.splice(to, 0, a.splice(from, 1)[0]);
        page.order = a;
        page.dirty = true;
    }

    Component.onCompleted: load()

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Panel layout") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Grab a block and drag it — the panel takes this order once you apply.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        Item {
            id: stage
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            readonly property real scale: Math.min(1, width / Math.max(1, page.sys.panelW))
            implicitHeight: mock.implicitHeight * stage.scale

            ControlsView {
                id: mock
                sys: page.sys
                preview: true
                ccOrderOverride: page.order
                width: page.sys.panelW
                height: implicitHeight
                enabled: false
                transformOrigin: Item.TopLeft
                scale: stage.scale
            }

            Repeater {
                model: page.order

                Item {
                    id: grip
                    required property int index
                    required property string modelData
                    readonly property var blk: mock.ccBlock(grip.modelData)
                    property bool held: false

                    visible: grip.blk !== null && grip.blk.height > 0
                    width: stage.width
                    height: grip.blk ? grip.blk.height * stage.scale : 0
                    y: grip.blk ? grip.blk.y * stage.scale : 0
                    z: grip.held ? 10 : 1

                    Behavior on y {
                        enabled: !grip.held
                        NumberAnimation { duration: page.sys.animFade; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: grip.held
                               ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                               : (gripMa.containsMouse
                                  ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08)
                                  : "transparent")
                        border.width: grip.held ? 1 : 0
                        border.color: page.sys.colOn
                        Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: gripMa.containsMouse || grip.held
                            text: String.fromCodePoint(0xF01DD)
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize }
                        }
                    }

                    MouseArea {
                        id: gripMa
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: grip.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: grip
                        drag.axis: Drag.YAxis
                        drag.minimumY: 0
                        drag.maximumY: Math.max(0, stage.height - grip.height)

                        onPressed: grip.held = true
                        onReleased: {
                            grip.held = false;
                            page.move(grip.index, page.dropIndex(grip.y + grip.height / 2));
                            grip.y = Qt.binding(() => grip.blk ? grip.blk.y * stage.scale : 0);
                        }
                    }
                }
            }
        }
    }

    function dropIndex(y) {
        for (var i = 0; i < page.order.length; i++) {
            var b = mock.ccBlock(page.order[i]);
            if (!b) continue;
            if (y < (b.y + b.height / 2) * mockScale()) return i;
        }
        return page.order.length - 1;
    }
    function mockScale() { return mock.scale; }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Reset")
            onClicked: {
                page.sys.cfg.ccLayout = "";
                page.sys.saveCfg();
                page.load();
            }
        }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Apply")
            primary: true
            enabled: page.dirty
            onClicked: {
                page.sys.cfg.ccLayout = page.order.join(",");
                page.sys.saveCfg();
                page.dirty = false;
            }
        }
    }
}
