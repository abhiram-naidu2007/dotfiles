import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: page

    property var sys
    property bool applied: false

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys
        visible: Compositor.isHyprland || Compositor.isI3

        SetLabel { sys: page.sys; text: page.sys.tr("Keyboard layouts") }
        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Comma-separated XKB codes, for example us,tr. Change shortcuts separately with Super+/.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
        TextField {
            id: layoutsField
            Layout.fillWidth: true
            placeholderText: "us,tr"
            text: page.sys.cfg.keyboardLayouts
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
            leftPadding: 12; rightPadding: 12; topPadding: 9; bottomPadding: 9
            selectByMouse: true
            selectionColor: page.sys.colOn
            background: Rectangle {
                radius: 10
                color: Pal.a(0.06)
                border.width: 1
                border.color: parent.activeFocus ? page.sys.colOn : page.sys.colLine
            }
            onAccepted: page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text)
        }
        TextField {
            id: variantsField
            Layout.fillWidth: true
            placeholderText: page.sys.tr("Variants (empty uses defaults)")
            text: page.sys.cfg.keyboardVariants
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
            leftPadding: 12; rightPadding: 12; topPadding: 9; bottomPadding: 9
            selectByMouse: true
            selectionColor: page.sys.colOn
            background: Rectangle {
                radius: 10
                color: Pal.a(0.06)
                border.width: 1
                border.color: parent.activeFocus ? page.sys.colOn : page.sys.colLine
            }
            onAccepted: page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text)
        }
        TextField {
            id: optionsField
            Layout.fillWidth: true
            placeholderText: "grp:alt_shift_toggle"
            text: page.sys.cfg.keyboardOptions
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
            leftPadding: 12; rightPadding: 12; topPadding: 9; bottomPadding: 9
            selectByMouse: true
            selectionColor: page.sys.colOn
            background: Rectangle {
                radius: 10
                color: Pal.a(0.06)
                border.width: 1
                border.color: parent.activeFocus ? page.sys.colOn : page.sys.colLine
            }
            onAccepted: page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text)
        }
        Text {
            Layout.fillWidth: true
            visible: page.sys.keyboardInputError.length > 0
            text: page.sys.keyboardInputError
            color: page.sys.colCrit
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
        SetButton {
            sys: page.sys
            text: page.sys.tr("Apply layouts")
            onClicked: page.applied = page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text)
        }
        Text {
            visible: page.applied && page.sys.keyboardInputError.length === 0
            text: page.sys.tr("Layouts applied")
            color: page.sys.colOn
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: Compositor.isNiri
        text: page.sys.tr("On Niri, set layouts in ~/.config/niri/config.kdl; this file survives updates.")
        color: page.sys.colMuted
        wrapMode: Text.WordWrap
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Pointer") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Pointer speed")
            from: -1; to: 1; step: 0.05
            decimals: 2
            value: page.sys.cfg.mouseSens
            onMoved: v => { page.sys.cfg.mouseSens = v; page.sys.applyInput(); }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("0 is the speed the mouse reports. Left is slower, right is faster.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Raw input")
            sub: page.sys.tr("No acceleration: the same hand movement always moves the pointer the same distance.")
            on: page.sys.cfg.mouseRaw
            onToggled: v => { page.sys.cfg.mouseRaw = v; page.sys.applyInput(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Reset") }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Reset to defaults")
            onClicked: {
                page.sys.cfg.mouseSens = 0;
                page.sys.cfg.mouseRaw = false;
                page.sys.applyInput();
            }
        }
    }
}
