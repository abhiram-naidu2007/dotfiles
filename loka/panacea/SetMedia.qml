import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Player") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Media page")
            sub: page.sys.tr("Cover art, seeking and switching the audio source.")
            on: page.sys.cfg.featMedia
            onToggled: v => { page.sys.cfg.featMedia = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Now playing in the collapsed island")
            on: page.sys.cfg.featPlayer
            onToggled: v => { page.sys.cfg.featPlayer = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Sound") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Volume and devices")
            on: page.sys.cfg.featAudio
            onToggled: v => { page.sys.cfg.featAudio = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Show a burst when volume changes")
            sub: page.sys.tr("A bar over the screen for the volume and brightness keys.")
            on: page.sys.cfg.featOsd
            onToggled: v => { page.sys.cfg.featOsd = v; page.sys.saveCfg(); }
        }
    }

}
