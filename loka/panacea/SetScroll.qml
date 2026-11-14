import QtQuick
import QtQuick.Controls

ScrollBar {
    id: sb

    property var sys

    policy: ScrollBar.AsNeeded
    implicitWidth: 6

    contentItem: Rectangle {
        implicitWidth: 6
        radius: 3
        color: Qt.rgba(sb.sys.colFg.r, sb.sys.colFg.g, sb.sys.colFg.b,
                       sb.pressed ? 0.34 : (sb.hovered ? 0.26 : 0.16))
        opacity: sb.size < 1 ? 1 : 0
        Behavior on color { ColorAnimation { duration: sb.sys.animFade } }
        Behavior on opacity { NumberAnimation { duration: sb.sys.animFade } }
    }

    background: Item {}
}
