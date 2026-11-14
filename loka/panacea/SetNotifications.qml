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
            label: page.sys.tr("Notification service")
            sub: page.sys.tr("Turn off if the system already runs its own notification daemon.")
            on: page.sys.cfg.featNotifications
            onToggled: v => { page.sys.cfg.featNotifications = v; page.sys.saveCfg(); }
        }

    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Timing and count") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("How long a normal one stays")
            from: 1000; to: 20000; step: 500
            value: page.sys.cfg.notifTimeout
            valueText: (page.sys.cfg.notifTimeout / 1000).toFixed(1) + " s"
            onMoved: v => { page.sys.cfg.notifTimeout = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("How long a critical one stays")
            visible: page.detailsOpen
            from: 0; to: 60000; step: 1000
            value: page.sys.cfg.notifCritTimeout
            valueText: page.sys.cfg.notifCritTimeout === 0
                       ? page.sys.tr("until answered")
                       : (page.sys.cfg.notifCritTimeout / 1000).toFixed(0) + " s"
            onMoved: v => { page.sys.cfg.notifCritTimeout = v; page.sys.saveCfg(); }
        }

        SetButton {
            sys: page.sys
            text: page.detailsOpen ? page.sys.tr("Hide details") : page.sys.tr("Detailed settings")
            onClicked: page.detailsOpen = !page.detailsOpen
        }

    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Content") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Show the body in the card")
            sub: page.sys.tr("Off — only the app and the title are shown.")
            on: page.sys.cfg.notifPreview
            onToggled: v => { page.sys.cfg.notifPreview = v; page.sys.saveCfg(); }
        }

    }
}
