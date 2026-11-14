pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: lan

    property color color: "#ffffff"
    property real stroke: lan.height <= 20 ? 1 : 2

    implicitWidth: 18
    implicitHeight: 18

    readonly property real boxW: lan.width * 0.40
    readonly property real boxH: lan.height * 0.26

    Rectangle {
        x: (lan.width - lan.boxW) / 2
        y: 0
        width: lan.boxW
        height: lan.boxH
        color: "transparent"
        border.color: lan.color
        border.width: lan.stroke
        radius: lan.stroke
    }

    Rectangle {
        x: (lan.width - lan.stroke) / 2
        y: lan.boxH
        width: lan.stroke
        height: lan.height / 2 - lan.boxH
        color: lan.color
    }

    Rectangle {
        x: lan.boxW / 2 - lan.stroke / 2
        y: lan.height / 2 - lan.stroke / 2
        width: lan.width - lan.boxW + lan.stroke
        height: lan.stroke
        color: lan.color
    }

    Repeater {
        model: [0, 1]
        Rectangle {
            required property int modelData
            x: modelData === 0 ? lan.boxW / 2 - lan.stroke / 2
                               : lan.width - lan.boxW / 2 - lan.stroke / 2
            y: lan.height / 2
            width: lan.stroke
            height: lan.height - lan.boxH - lan.height / 2
            color: lan.color
        }
    }

    Repeater {
        model: [0, 1]
        Rectangle {
            required property int modelData
            x: modelData === 0 ? 0 : lan.width - lan.boxW
            y: lan.height - lan.boxH
            width: lan.boxW
            height: lan.boxH
            color: "transparent"
            border.color: lan.color
            border.width: lan.stroke
            radius: lan.stroke
        }
    }
}
