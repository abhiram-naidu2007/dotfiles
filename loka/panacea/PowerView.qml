pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property int armed: -1
    property int current: 0

    Timer {
        id: disarm
        interval: 4000
        onTriggered: view.armed = -1
    }

    readonly property var actions: view.sys.cfg.featLock ? view.allActions
                                 : view.allActions.filter(a => a.id !== "lock")
    readonly property var allActions: [
        { id: "sleep", icon: String.fromCodePoint(0xF0904), label: view.sys.tr("Sleep"),
          cmd: "systemctl suspend -i || systemctl suspend || loginctl suspend",
          accent: view.sys.tint("#38bdf8") },
        { id: "lock", instant: true, icon: String.fromCodePoint(0xF033E),
          label: view.sys.tr("Lock"),
          cmd: "$HOME/.config/panacea/scripts/lock.sh",
          accent: view.sys.tint("#a78bfa") },
        { id: "logout", icon: String.fromCodePoint(0xF0343), label: view.sys.tr("Log out"),
          cmd: "i3-msg exit",
          accent: view.sys.colWarn },
        { id: "reboot", icon: String.fromCodePoint(0xF0709), label: view.sys.tr("Restart"),
          cmd: "systemctl reboot -i || systemctl reboot || loginctl reboot",
          accent: view.sys.tint("#fb923c") },
        { id: "poweroff", icon: String.fromCodePoint(0xF0425), label: view.sys.tr("Shut down"),
          cmd: "systemctl poweroff -i || systemctl poweroff || loginctl poweroff",
          accent: view.sys.colCrit }
    ]

    function trigger(i) {
        if (i < 0 || i >= actions.length) return;
        if (!actions[i].instant && view.armed !== i) {
            view.armed = i;
            view.current = i;
            disarm.restart();
            return;
        }
        disarm.stop();
        view.sys.runDetached(actions[i].cmd);
        view.sys.collapse();
    }

    focus: true
    Keys.onEscapePressed: view.sys.collapse()
    Keys.onReturnPressed: trigger(current)
    Keys.onLeftPressed:  if (current > 0) { current--; armed = -1 }
    Keys.onRightPressed: if (current < actions.length - 1) { current++; armed = -1 }
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        Text {
            Layout.fillWidth: true
            text: view.armed >= 0
                  ? view.sys.tr("Press again to confirm: ") + view.actions[view.armed].label
                  : view.sys.tr("Power")
            color: view.armed >= 0 ? view.actions[view.armed].accent : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 11

            Repeater {
                model: view.actions

                Rectangle {
                    id: rectang

                    required property int index
                    required property var modelData

                    readonly property bool isArmed: view.armed === index
                    readonly property bool isCurrent: view.current === index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 104
                    radius: 16

                    color: btnMa.containsMouse || isCurrent
                           ? Pal.a(0.10) : Pal.a(0.05)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: rectang.modelData.accent
                        opacity: parent.isArmed ? 0.22 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    border.color: isArmed ? modelData.accent
                                : isCurrent ? Pal.a(0.22)
                                            : view.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    scale: btnMa.pressed ? 0.94 : (btnMa.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                    ColumnLayout {
                        id: body
                        anchors.centerIn: parent
                        spacing: 9

                        Item {
                            id: itemrt

                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            readonly property color ink: rectang.modelData.accent

                            Item {
                                anchors.fill: parent
                                visible: rectang.modelData.id === "sleep"

                                Text {
                                    x: 1; y: 15
                                    text: "Z"
                                    color: itemrt.ink
                                    font { family: view.sys.fontBody; pixelSize: 19; bold: true }
                                }
                                Text {
                                    x: 17; y: 1
                                    text: "z"
                                    color: itemrt.ink
                                    font { family: view.sys.fontBody; pixelSize: 10; bold: true }
                                }
                                Text {
                                    x: 24; y: 8
                                    text: "z"
                                    color: itemrt.ink
                                    font { family: view.sys.fontBody; pixelSize: 14; bold: true }
                                }
                            }

                            Glyph {
                                anchors.fill: parent
                                visible: rectang.modelData.id !== "sleep"
                                glyph: rectang.modelData.icon
                                color: parent.ink
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize + 8
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: rectang.isArmed ? view.sys.tr("Confirm") : rectang.modelData.label
                            color: rectang.isArmed ? view.sys.colFg : view.sys.colMuted
                            font {
                                family: view.sys.fontFam
                                pixelSize: view.sys.fontSize - 4
                                bold: rectang.isArmed
                            }
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { view.current = rectang.index; view.forceActiveFocus() }
                        onClicked: view.trigger(rectang.index)
                    }
                }
            }
        }
    }
}
