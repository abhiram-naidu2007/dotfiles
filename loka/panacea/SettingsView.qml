pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: view

    property var sys
    property int tab: 0

    implicitWidth: 980
    implicitHeight: 620

    readonly property var sections: [
        { id: "bar",     title: view.sys.tr("Bar and island"),   g: 0xF12E1, page: "SetBarIsland.qml",
          sub: view.sys.tr("How the island sits on the edge, and what it unfolds into."),
          keys: "notch island pill bar height width cpu gpu load temperature" },
        { id: "media",   title: view.sys.tr("Media"),          g: 0xF0387, page: "SetMedia.qml",
          sub: view.sys.tr("The player, cover art, and what shows in the collapsed island."),
          keys: "player music cover" },
        { id: "clock",   title: view.sys.tr("Clock and date"),   g: 0xF0150, page: "SetClock.qml",
          sub: view.sys.tr("Time format, time zone, and the line beneath it."),
          keys: "clock time date timezone" },
        { id: "look",    title: view.sys.tr("Appearance"),     g: 0xF03D8, page: "SetAppearance.qml",
          sub: view.sys.tr("Widgets, fonts, and system appearance."),
          keys: "theme nothing font size sounds audio haptics" },
        { id: "weather", title: view.sys.tr("Weather"),        g: 0xF0590, page: "SetWeather.qml",
          sub: view.sys.tr("Key, city and units for the weather."),
          keys: "weather temperature city openweather api key celsius fahrenheit "
                + "" },
        { id: "motion",  title: view.sys.tr("Motion"),         g: 0xF15B6, page: "SetMotion.qml",
          sub: view.sys.tr("How fast the shell animates, or whether it animates at all."),
          keys: "animation speed bounce mascot character eyes cursor" },
        { id: "notif",   title: view.sys.tr("Notifications"),  g: 0xF009A, page: "SetNotifications.qml",
          sub: view.sys.tr("How many cards stay on screen, and for how long."),
          keys: "notifications dnd toast" },
        { id: "cc",      title: view.sys.tr("Quick settings"), g: 0xF062E, page: "SetControlCenter.qml",
          sub: view.sys.tr("The quick settings layout — blocks are rearranged by hand."),
          keys: "quick settings tiles layout wifi bluetooth" },
        { id: "display", title: view.sys.tr("Display"),        g: 0xF0379, page: "SetDisplay.qml",
          sub: view.sys.tr("Resolution, refresh rate and scale of the connected screens."),
          keys: "display monitor resolution refresh scale layout placement detect island "
                + "" },
        { id: "input",   title: view.sys.tr("Input"),           g: 0xF037D, page: "SetInput.qml",
          sub: view.sys.tr("Pointer speed and acceleration."),
          keys: "mouse keyboard layouts xkb pointer cursor sensitivity speed accel acceleration raw input flat "
                + "vpn" },
        { id: "system",  title: view.sys.tr("System"),         g: 0xF0493, page: "SetSystem.qml",
          sub: view.sys.tr("What the machine is made of, and what it is busy with."),
          keys: "about system cpu ram temperature" }
    ]

    readonly property var groups: [
        { id: "island", title: view.sys.tr("Island"), g: 0xF12E1, pages: ["bar", "media", "clock"] },
        { id: "appearance", title: view.sys.tr("Appearance"), g: 0xF03D8, pages: ["look", "weather", "motion"] },
        { id: "controls", title: view.sys.tr("Controls"), g: 0xF062E, pages: ["cc", "notif"] },
        { id: "devices", title: view.sys.tr("Devices"), g: 0xF0379, pages: ["display", "input"] },
        { id: "system", title: view.sys.tr("System"), g: 0xF0493, pages: ["system"] }
    ]

    function groupForPage(pageId) {
        for (var i = 0; i < groups.length; i++)
            if (groups[i].pages.indexOf(pageId) >= 0) return groups[i];
        return groups[0];
    }
    function pagesForGroup(group) {
        var result = [];
        for (var i = 0; i < group.pages.length; i++)
            for (var j = 0; j < sections.length; j++)
                if (sections[j].id === group.pages[i]) result.push({ index: j, title: sections[j].title });
        return result;
    }
    function groupMatches(group) {
        if (!view.query.length) return true;
        if (group.title.toLowerCase().indexOf(view.query.toLowerCase()) >= 0) return true;
        var pages = pagesForGroup(group);
        for (var i = 0; i < pages.length; i++)
            if (view.matches(sections[pages[i].index])) return true;
        return false;
    }
    function goGroup(group) {
        var pages = pagesForGroup(group);
        for (var i = 0; i < pages.length; i++)
            if (view.matches(sections[pages[i].index])) { view.go(pages[i].index); return; }
        if (pages.length) view.go(pages[0].index);
    }

    readonly property var section: sections[Math.max(0, Math.min(sections.length - 1, tab))]
    readonly property var activeGroup: groupForPage(section.id)
    readonly property var groupPages: pagesForGroup(activeGroup)

    function goToSection(id) {
        if (!id) return;
        for (var i = 0; i < view.sections.length; i++) {
            if (view.sections[i].id === id) { view.go(i); break; }
        }
        view.sys.settingsSection = "";
    }
    Component.onCompleted: view.goToSection(view.sys.settingsSection)
    Connections {
        target: view.sys
        function onSettingsSectionChanged() { view.goToSection(view.sys.settingsSection); }
    }

    property var hist: [0]
    property int histAt: 0
    function go(i) {
        if (i === view.tab) return;
        var h = view.hist.slice(0, view.histAt + 1);
        h.push(i);
        view.hist = h;
        view.histAt = h.length - 1;
        view.tab = i;
    }
    function back()    { if (canBack)    { view.histAt--; view.tab = view.hist[view.histAt]; } }
    function forward() { if (canForward) { view.histAt++; view.tab = view.hist[view.histAt]; } }
    readonly property bool canBack:    histAt > 0
    readonly property bool canForward: histAt < hist.length - 1

    property string query: ""
    function matches(s) {
        if (view.query.length === 0) return true;
        var q = view.query.toLowerCase();
        return s.title.toLowerCase().indexOf(q) >= 0 || s.keys.toLowerCase().indexOf(q) >= 0;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            readonly property real navW: {
                var m = 0;
                for (var i = 0; i < view.groups.length; i++)
                    m = Math.max(m, navMetric.advanceWidth(view.groups[i].title));
                return Math.max(196, Math.min(300, Math.ceil(m * 1.25) + 64));
            }
            FontMetrics {
                id: navMetric
                font.family: view.sys.fontBody
                font.pixelSize: view.sys.fontSize - 1
            }

            Layout.fillWidth: false
            Layout.preferredWidth: navW
            Layout.minimumWidth: navW
            Layout.maximumWidth: navW
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 12
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b,
                               searchInput.activeFocus ? 0.12 : 0.07)
                Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0349)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: view.sys.colFg
                    clip: true
                    selectByMouse: true
                    selectionColor: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 2 }
                    onTextChanged: view.query = text
                    onAccepted: {
                        for (var i = 0; i < view.sections.length; i++)
                            if (view.matches(view.sections[i])) { view.go(i); break; }
                    }
                    Keys.onEscapePressed: { text = ""; focus = false; }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: view.sys.tr("Search Settings")
                        color: view.sys.colMuted
                        font: searchInput.font
                    }
                }
            }

            ListView {
                id: nav
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: view.groups
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: SetScroll { sys: view.sys }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, nav.contentHeight - nav.height);
                        nav.contentY = Math.max(0, Math.min(max, nav.contentY - d));
                    }
                }

                delegate: Rectangle {
                    id: navItem
                    required property int index
                    required property var modelData
                    readonly property bool active: view.activeGroup.id === navItem.modelData.id
                    readonly property bool shown: view.groupMatches(navItem.modelData)

                    width: nav.width
                    height: shown ? 42 : 0
                    visible: shown
                    radius: 13
                    color: navItem.active
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                           : (navMa.containsMouse
                              ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                              : "transparent")
                    border.width: 1
                    border.color: navItem.active
                                  ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                  : "transparent"
                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                    Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 7
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 9
                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(navItem.modelData.g)
                                color: navItem.active ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: navItem.modelData.title
                            color: navItem.active ? view.sys.colFg : view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 1 }
                        }
                    }

                    MouseArea {
                        id: navMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.goGroup(navItem.modelData)
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [{ g: 0xF004D, fwd: false }, { g: 0xF0054, fwd: true }]
                    Rectangle {
                        id: navArrow
                        required property var modelData
                        readonly property bool armed: navArrow.modelData.fwd ? view.canForward : view.canBack

                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 9
                        opacity: navArrow.armed ? 1 : 0.35
                        color: arrowMa.containsMouse && navArrow.armed
                               ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(navArrow.modelData.g)
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }

                        MouseArea {
                            id: arrowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: navArrow.armed
                            cursorShape: Qt.PointingHandCursor
                            onClicked: navArrow.modelData.fwd ? view.forward() : view.back()
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: view.groupPages
                    Rectangle {
                        id: pageTab
                        required property var modelData
                        readonly property bool selected: view.tab === modelData.index
                        Layout.preferredWidth: Math.max(96, pageTabLabel.implicitWidth + 24)
                        Layout.preferredHeight: 32
                        radius: 10
                        color: selected ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                                        : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        Text {
                            id: pageTabLabel
                            anchors.centerIn: parent
                            text: pageTab.modelData.title
                            color: pageTab.selected ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 2 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.go(pageTab.modelData.index)
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Flickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000
                ScrollBar.vertical: SetScroll { sys: view.sys }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, scroll.contentHeight - scroll.height);
                        scroll.contentY = Math.max(0, Math.min(max, scroll.contentY - d));
                    }
                }

                ColumnLayout {
                    id: pageCol
                    width: scroll.width - 12
                    spacing: 12

                    SetHeader {
                        sys: view.sys
                        glyph: String.fromCodePoint(view.section.g)
                        title: view.section.title
                        sub: view.section.sub
                    }

                    Loader {
                        id: pageLoader
                        Layout.fillWidth: true

                        function reload() { setSource(view.section.page, { sys: view.sys }); }
                        Component.onCompleted: reload()

                        Connections {
                            target: view
                            function onTabChanged() { pageLoader.reload(); }
                        }
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }

    onTabChanged: scroll.contentY = 0
}
