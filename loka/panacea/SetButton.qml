import QtQuick
import QtQuick.Layouts

Rectangle {
    id: btn

    property var sys
    property string text: ""
    property bool primary: false

    signal clicked()

    Layout.preferredWidth: Math.max(112, btnLabel.implicitWidth + 26)
    Layout.preferredHeight: 32
    radius: 10
    opacity: btn.enabled ? 1 : 0.4

    color: btn.primary
           ? (ma.containsMouse
              ? Qt.rgba(btn.sys.colOn.r, btn.sys.colOn.g, btn.sys.colOn.b, 0.34)
              : Qt.rgba(btn.sys.colOn.r, btn.sys.colOn.g, btn.sys.colOn.b, 0.22))
           : (ma.containsMouse ? Pal.a(0.10) : "transparent")
    border.width: 1
    border.color: btn.primary ? btn.sys.colOn : btn.sys.colLine

    Behavior on color { ColorAnimation { duration: btn.sys.animFade } }
    Behavior on opacity { NumberAnimation { duration: btn.sys.animFade } }

    Text {
        id: btnLabel
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? btn.sys.colFg : btn.sys.colMuted
        font {
            family: btn.sys.fontBody
            pixelSize: btn.sys.fontSize - 3
            bold: btn.primary
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
