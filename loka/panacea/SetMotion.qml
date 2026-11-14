import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var sys
    property bool detailsOpen: false

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Panacea character")
            sub: page.sys.tr("Always visible in the island, and wakes up for 2.5 minutes from time to time.")
            on: page.sys.cfg.mascotEnabled
            onToggled: value => { page.sys.cfg.mascotEnabled = value; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Reduce motion")
            sub: page.sys.tr("The shell stops moving entirely: every duration counts as zero.")
            on: page.sys.cfg.reduceMotion
            onToggled: value => { page.sys.cfg.reduceMotion = value; page.sys.saveCfg(); }
        }

        SetButton {
            sys: page.sys
            text: page.detailsOpen ? page.sys.tr("Hide details") : page.sys.tr("Detailed settings")
            onClicked: page.detailsOpen = !page.detailsOpen
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Movement (size / position)")
            from: 80; to: 900; step: 10
            value: page.sys.cfg.animMove
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animMove = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Fades & colour")
            from: 40; to: 600; step: 10
            value: page.sys.cfg.animFade
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animFade = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Hover response")
            from: 20; to: 400; step: 10
            value: page.sys.cfg.animHover
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animHover = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Bounce")
            from: 0; to: 100; step: 1
            value: page.sys.cfg.animBounce
            suffix: "%"
            onMoved: v => { page.sys.cfg.animBounce = v; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            visible: page.detailsOpen
            text: page.sys.tr("Bounce — how much the simulated oscillator overshoots the target before it settles.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }
}
