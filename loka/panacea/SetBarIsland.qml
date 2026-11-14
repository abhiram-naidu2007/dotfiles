import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var sys
    property bool detailsOpen: false
    readonly property bool notch: page.sys.cfg.notchMode

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Notch mode")
            sub: page.sys.tr("The island sits flush against the screen edge and flares into it with concave corners. Turn off and it becomes a separate capsule with a gap from the edge.")
            on: page.notch
            onToggled: value => { page.sys.cfg.notchMode = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Auto-hide")
            sub: page.sys.tr("The island slides off the edge and stops reserving space, so windows get the whole screen. Point at the edge to bring it back.")
            on: page.sys.cfg.pillAutoHide
            onToggled: value => { page.sys.cfg.pillAutoHide = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Floating overlay mode")
            sub: page.sys.tr("The island floats over windows without reserving the top row, so windows do not shrink or jump.")
            on: page.sys.cfg.pillOverlay
            onToggled: value => { page.sys.cfg.pillOverlay = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Keep bar visible on expand")
            sub: page.sys.tr("Keep the top bar/island visible in its collapsed state while opening quick settings and pages as a separate floating card below it.")
            on: page.sys.cfg.pillKeepVisible
            onToggled: value => { page.sys.cfg.pillKeepVisible = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("System load on island")
            sub: page.sys.tr("Show CPU and GPU usage and temperatures on the collapsed island.")
            on: page.sys.cfg.systemLoadOnIsland
            onToggled: value => { page.sys.cfg.systemLoadOnIsland = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Close Panacea windows on Super+Q")
            visible: page.detailsOpen
            sub: page.sys.tr("When a Panacea panel is open, Super+Q closes it. Disable this to always close the active application.")
            on: page.sys.cfg.closePanaceaFirst
            onToggled: value => { page.sys.cfg.closePanaceaFirst = value; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: page.notch
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Notch flare")
            from: 0; to: 32; step: 1
            value: page.sys.cfg.notchFlare
            suffix: "px"
            onMoved: v => { page.sys.cfg.notchFlare = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.notch
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Edge gap")
            from: 0; to: 48; step: 1
            value: page.sys.cfg.islandGap
            suffix: "px"
            onMoved: v => { page.sys.cfg.islandGap = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.notch
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Capsule radius")
            from: 0; to: 40; step: 1
            value: page.sys.cfg.islandRadius
            valueText: page.sys.cfg.islandRadius === 0
                       ? page.sys.tr("by height") : page.sys.cfg.islandRadius + " px"
            onMoved: v => { page.sys.cfg.islandRadius = v; page.sys.saveCfg(); }
        }
    }

    SetButton {
        sys: page.sys
        text: page.detailsOpen ? page.sys.tr("Hide details") : page.sys.tr("Detailed settings")
        onClicked: page.detailsOpen = !page.detailsOpen
    }

    SetCard {
        sys: page.sys
        visible: page.detailsOpen

        SetLabel { sys: page.sys; text: page.sys.tr("Sizes") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Bar height")
            from: 24; to: 72; step: 1
            value: page.sys.cfg.pillH
            suffix: "px"
            onMoved: v => { page.sys.cfg.pillH = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Collapsed width")
            from: 120; to: 640; step: 4
            value: page.sys.cfg.collapsedW
            suffix: "px"
            onMoved: v => { page.sys.cfg.collapsedW = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Expanded width")
            from: 380; to: 900; step: 10
            value: page.sys.cfg.panelW
            suffix: "px"
            onMoved: v => { page.sys.cfg.panelW = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Expanded height")
            from: 260; to: 1000; step: 10
            value: page.sys.cfg.expandedH
            suffix: "px"
            onMoved: v => { page.sys.cfg.expandedH = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys
        visible: page.detailsOpen

        SetLabel { sys: page.sys; text: page.sys.tr("Behaviour") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Drag the island with the mouse")
            sub: page.sys.tr("The island can be grabbed right on the screen and dragged to another edge.")
            on: page.sys.cfg.pillDrag
            onToggled: value => { page.sys.cfg.pillDrag = value; page.sys.saveCfg(); }
        }
    }
}
