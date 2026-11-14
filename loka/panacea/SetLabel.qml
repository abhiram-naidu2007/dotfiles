import QtQuick
import QtQuick.Layouts

Text {
    id: cap

    property var sys

    Layout.fillWidth: true
    Layout.topMargin: 4
    color: Qt.rgba(cap.sys.colFg.r, cap.sys.colFg.g, cap.sys.colFg.b, 0.35)
    font {
        family: cap.sys.fontBody
        pixelSize: cap.sys.fontSize - 5
        letterSpacing: 1.4
        capitalization: Font.AllUppercase
        bold: true
    }
}
