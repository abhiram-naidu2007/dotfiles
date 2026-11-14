pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: page

    property var sys
    property bool detailsOpen: false

    Layout.fillWidth: true
    spacing: 12

    SetButton {
        sys: page.sys
        text: page.detailsOpen ? page.sys.tr("Hide details") : page.sys.tr("Detailed settings")
        onClicked: page.detailsOpen = !page.detailsOpen
    }

    SetCard {
        sys: page.sys
        visible: page.detailsOpen

        SetLabel { sys: page.sys; text: page.sys.tr("Appearance") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Muted text")
            from: 0.2; to: 1.0; step: 0.05
            decimals: 2
            value: page.sys.cfg.mutedAlpha
            onMoved: v => { page.sys.cfg.mutedAlpha = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Terminal transparency")
            from: 0.5; to: 1.0; step: 0.01
            decimals: 2
            value: page.sys.cfg.termAlpha
            onMoved: v => {
                page.sys.cfg.termAlpha = v;
                page.sys.saveCfg();
                page.sys.applyTermAlpha();
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Ghostty background. 1.00 is solid. Applies to open windows at once."
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Fonts") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Text size")
            from: 10; to: 24; step: 1
            value: page.sys.cfg.fontSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.fontSize = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Icon size")
            visible: page.detailsOpen
            from: 12; to: 28; step: 1
            value: page.sys.cfg.iconSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.iconSize = v; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Body font")
            visible: page.detailsOpen
            options: page.sys.fontList
            value: page.sys.cfg.fontBody || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontBody = id; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Display font")
            visible: page.detailsOpen
            options: page.sys.fontList
            value: page.sys.cfg.fontDisplay || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontDisplay = id; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Icon font")
            visible: page.detailsOpen
            options: page.sys.fontList
            value: page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontFam = id; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Sounds") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("System sound effects")
            sub: page.sys.tr("Charging, Bluetooth, screenshots, voice input")
            on: page.sys.cfg.uiSounds !== false
            onToggled: value => {
                page.sys.cfg.uiSounds = value;
                page.sys.saveCfg();
                if (value) page.sys.playSound("connect");
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            visible: page.sys.cfg.uiSounds !== false && page.detailsOpen

            Repeater {
                model: [
                    { id: "charge",      label: page.sys.tr("Charging"),     icon: "󰂄" },
                    { id: "connect",     label: "Bluetooth",               icon: "󰂯" },
                    { id: "disconnect",  label: page.sys.tr("Disconnect"),  icon: "󰂲" },
                    { id: "screenshot",  label: page.sys.tr("Screenshot"),    icon: "󰄀" },
                    { id: "voice_start", label: page.sys.tr("Voice"),       icon: "󰍬" }
                ]

                Rectangle {
                    id: sndBtn

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: sndMa.containsMouse ? Pal.a(0.12) : Pal.a(0.05)
                    border.color: sndMa.containsMouse ? page.sys.colOn : page.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: sndBtn.modelData.icon
                            color: sndMa.containsMouse ? page.sys.colOn : page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: sndBtn.modelData.label
                            color: sndMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: sndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.sys.playSound(sndBtn.modelData.id)
                    }
                }
            }
        }
    }
}
