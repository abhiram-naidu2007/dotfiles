import QtQuick

Item {
    id: ft

    property string value: ""
    property color  textColor: "#ffffff"
    property string fontFam: "monospace"
    property int    pixelSize: 15
    property bool   bold: true
    property int    dur: 190
    property real   minWidth: 0

    property string shown: value

    implicitWidth: Math.max(minWidth, label.implicitWidth)
    implicitHeight: label.implicitHeight
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: ft.dur; easing.type: Easing.InOutCubic }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        text: ft.shown
        color: ft.textColor
        font { family: ft.fontFam; pixelSize: ft.pixelSize; bold: ft.bold }
    }

    onValueChanged: {
        if (value === shown) return;
        flip.restart();
    }

    SequentialAnimation {
        id: flip

        ParallelAnimation {
            NumberAnimation {
                target: label; property: "opacity"; to: 0
                duration: Math.round(ft.dur * 0.45); easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: label; property: "y"; to: -ft.implicitHeight
                duration: Math.round(ft.dur * 0.45); easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                ft.shown = ft.value;
                label.y = ft.implicitHeight;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: label; property: "opacity"; to: 1
                duration: Math.round(ft.dur * 0.55); easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: label; property: "y"; to: 0
                duration: Math.round(ft.dur * 0.55); easing.type: Easing.OutCubic
            }
        }
    }
}
