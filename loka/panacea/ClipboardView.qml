pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    ListModel { id: clipmodel }
    property string query: ""
    property var pins: []
    property var pinnedLookup: ({})

    Process {
        id: pLoadPins
        command: ["sh", "-c", "cat \"$HOME/.config/panacea/clipboard_pins.json\" 2>/dev/null || echo '[]'"]
        stdout: SplitParser {
            splitMarker: "\0"
            onRead: data => {
                try {
                    view.pins = JSON.parse(data.trim() || "[]");
                } catch (e) {
                    view.pins = [];
                }
                view.reload();
            }
        }
    }

    Process { id: pSavePins }

    function savePins() {
        var json = JSON.stringify(view.pins);
        pSavePins.command = [
            "sh", "-c",
            "mkdir -p \"$HOME/.config/panacea\" && printf '%s' \"$1\" > \"$HOME/.config/panacea/clipboard_pins.json\"",
            "_", json
        ];
        pSavePins.running = true;
    }

    function togglePin(text) {
        if (!text || !text.length) return;
        var idx = view.pins.indexOf(text);
        if (idx >= 0) {
            view.pins.splice(idx, 1);
        } else {
            view.pins.unshift(text);
        }
        view.savePins();
        view.reload();
    }

    function detectType(text) {
        if (!text) return "text";
        var t = text.trim();
        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/i.test(t)) return "color";
        if (/^(https?:\/\/[^\s]+|www\.[^\s]+)$/i.test(t)) return "url";
        if (t.startsWith("/") || t.startsWith("~/") || t.startsWith("file://")) {
            var ext = t.split(".").pop().toLowerCase();
            if (["png", "jpg", "jpeg", "webp", "gif", "svg", "ico"].indexOf(ext) >= 0)
                return "image-file";
            return "file";
        }
        return "text";
    }

    function expandPath(p) {
        if (!p) return "";
        var home = Quickshell.env("HOME") || "/home/ensi";
        if (p.startsWith("~/")) return home + p.substring(1);
        if (p.startsWith("file://")) return p.substring(7);
        return p;
    }

    function hexToRgb(hex) {
        var c = hex.replace("#", "");
        if (c.length === 3) c = c[0]+c[0] + c[1]+c[1] + c[2]+c[2];
        var num = parseInt(c.substring(0, 6), 16);
        var r = (num >> 16) & 255;
        var g = (num >> 8) & 255;
        var b = num & 255;
        return "rgb(" + r + ", " + g + ", " + b + ")";
    }

    function hexToHsl(hex) {
        var c = hex.replace("#", "");
        if (c.length === 3) c = c[0]+c[0] + c[1]+c[1] + c[2]+c[2];
        var num = parseInt(c.substring(0, 6), 16);
        var r = ((num >> 16) & 255) / 255;
        var g = ((num >> 8) & 255) / 255;
        var b = (num & 255) / 255;
        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var h = 0, s = 0, l = (max + min) / 2;
        if (max !== min) {
            var d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            switch (max) {
                case r: h = (g - b) / d + (g < b ? 6 : 0); break;
                case g: h = (b - r) / d + 2; break;
                case b: h = (r - g) / d + 4; break;
            }
            h /= 6;
        }
        return "hsl(" + Math.round(h * 360) + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)";
    }

    Process {
        id: pList
        command: ["sh", "-c", "cliphist list"]
        stdout: SplitParser {
            onRead: line => {
                var t = line.indexOf("\t");
                if (t < 0) return;
                var id = line.substring(0, t);
                var preview = line.substring(t + 1).trim();
                if (!preview.length) return;
                if (view.pinnedLookup[preview]) return;
                if (view.query.length &&
                    preview.toLowerCase().indexOf(view.query.toLowerCase()) < 0) return;
                if (list.model.count >= 60) return;
                list.model.append({
                    cid: id,
                    preview: preview,
                    isPinned: false,
                    isImage: /^\[\[\s*binary data/.test(preview)
                });
            }
        }
    }

    Process { id: pCopy }
    Process { id: pWipe; command: ["sh", "-c", "cliphist wipe"] }
    Process { id: pAction }

    function reload() {
        list.model.clear();
        list.currentIndex = 0;
        var q = view.query.toLowerCase();
        var pinnedSet = {};
        for (var i = 0; i < view.pins.length; i++) {
            var p = view.pins[i];
            if (!p || !p.length) continue;
            pinnedSet[p] = true;
            if (q.length && p.toLowerCase().indexOf(q) < 0) continue;
            list.model.append({
                cid: "",
                preview: p,
                isPinned: true,
                isImage: /^\[\[\s*binary data/.test(p)
            });
        }
        view.pinnedLookup = pinnedSet;
        pList.running = false;
        pList.running = true;
    }

    function copyAt(i) {
        if (i < 0 || i >= list.model.count) return;
        var item = list.model.get(i);
        if (item.isPinned) {
            pCopy.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", item.preview];
        } else {
            pCopy.command = ["sh", "-c", "printf '%s\\t' \"$1\" | cliphist decode | wl-copy", "_", item.cid];
        }
        pCopy.running = true;
        view.sys.collapse();
    }

    function copyDirect(text) {
        pCopy.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", text];
        pCopy.running = true;
        view.sys.collapse();
    }

    function openTarget(target) {
        pAction.command = ["sh", "-c", "xdg-open \"$1\" >/dev/null 2>&1 &", "_", target];
        pAction.running = true;
        view.sys.collapse();
    }

    Component.onCompleted: pLoadPins.running = true
    FocusGrabber { target: input }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 12
                color: Pal.a(0.06)
                border.color: input.activeFocus ? Pal.a(0.22) : view.sys.colLine
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 9

                    Text {
                        text: "󰅍"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                    }

                    TextField {
                        id: input
                        focus: true
                        Layout.fillWidth: true
                        placeholderText: view.sys.tr("Search clipboard")
                        color: view.sys.colFg
                        placeholderTextColor: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                        background: null
                        onTextEdited: { view.query = text; view.reload(); }

                        Keys.onEscapePressed: view.sys.collapse()
                        Keys.onReturnPressed: view.copyAt(list.currentIndex)
                        Keys.onDownPressed:
                            if (list.currentIndex < list.model.count - 1) list.currentIndex++
                        Keys.onUpPressed:
                            if (list.currentIndex > 0) list.currentIndex--
                    }

                    Text {
                        visible: view.sys.cfg.featVault
                        text: String.fromCodePoint(view.sys.vaultUnlocked ? 0xF0FC6 : 0xF033E)
                        color: view.sys.vaultUnlocked ? view.sys.colOk : (vaultMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: vaultMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.sys.togglePage("vault")
                        }
                    }

                    Text {
                        text: "󰩹"
                        color: wipeMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: wipeMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { pWipe.running = true; view.reload(); }
                        }
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 320)
            clip: true
            model: clipmodel
            spacing: 3
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000
            maximumFlickVelocity: 2600

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Pal.a(0.22) }
            }

            delegate: Rectangle {
                required property int index
                required property string cid
                required property string preview
                required property bool isPinned
                required property bool isImage
                
                id: rowDelegate
                width: list.width
                height: isImage && imgPath !== "" ? 64 : 40
                readonly property string imgPath: { var m = /\]\]\s+(\/\S+)$/.exec(preview); return m ? m[1] : ""; }
                readonly property string imgMeta: { var m = /binary data\s+(\d+)\s+KiB\s+(\w+)\s+(\S*)/.exec(preview); return m ? (m[2].toUpperCase() + "  ·  " + m[3] + "  ·  " + m[1] + " KiB") : ""; }
                radius: 10
                color: index === list.currentIndex ? Pal.a(0.12)
                     : rowMa.containsMouse ? view.sys.colHover : "transparent"
                border.color: isPinned ? Pal.a(0.18) : "transparent"
                border.width: isPinned ? 1 : 0
                Behavior on color { ColorAnimation { duration: 130 } }

                readonly property string cType: view.detectType(preview)
                readonly property bool isSelected: index === list.currentIndex || rowMa.containsMouse

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    spacing: 9

                    Text {
                        visible: isPinned
                        text: "󰤱"
                        color: view.sys.colCrit
                        font { family: view.sys.fontFam; pixelSize: 13 }
                    }

                    Item {
                        Layout.preferredWidth: rowDelegate.imgPath !== "" ? 72 : 20
                        Layout.preferredHeight: rowDelegate.imgPath !== "" ? 48 : 20
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            visible: rowDelegate.imgPath !== ""
                            radius: 8
                            color: Pal.a(0.06)
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: rowDelegate.imgPath !== "" ? "file://" + rowDelegate.imgPath : ""
                                sourceSize: Qt.size(144, 96)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: rowDelegate.cType === "color"
                            radius: 4
                            color: rowDelegate.cType === "color" ? preview.trim() : "transparent"
                            border.width: 1
                            border.color: Pal.a(0.3)
                        }

                        Image {
                            anchors.fill: parent
                            visible: rowDelegate.cType === "image-file"
                            source: rowDelegate.cType === "image-file" ? ("file://" + view.expandPath(preview.trim())) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: rowDelegate.cType !== "color" && rowDelegate.cType !== "image-file" && rowDelegate.imgPath === ""
                            text: isImage ? "󰋩"
                                : rowDelegate.cType === "url" ? "󰖟"
                                : rowDelegate.cType === "file" ? "󰉋"
                                : "󰈙"
                            color: rowDelegate.cType === "url" ? view.sys.colOn : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: isImage ? (rowDelegate.imgMeta !== "" ? view.sys.tr("Image") + "  ·  " + rowDelegate.imgMeta : view.sys.tr("Image (binary)")) : preview
                        color: view.sys.colFg
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6
                        visible: rowDelegate.isSelected

                        Rectangle {
                            visible: rowDelegate.cType === "color"
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 36
                            radius: 5
                            color: rgbMa.containsMouse ? Pal.a(0.22) : Pal.a(0.10)
                            Text {
                                anchors.centerIn: parent
                                text: "RGB"
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                            MouseArea {
                                id: rgbMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.copyDirect(view.hexToRgb(preview.trim()))
                            }
                        }

                        Rectangle {
                            visible: rowDelegate.cType === "color"
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 36
                            radius: 5
                            color: hslMa.containsMouse ? Pal.a(0.22) : Pal.a(0.10)
                            Text {
                                anchors.centerIn: parent
                                text: "HSL"
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                            MouseArea {
                                id: hslMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.copyDirect(view.hexToHsl(preview.trim()))
                            }
                        }

                        Rectangle {
                            visible: rowDelegate.cType === "url"
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 26
                            radius: 5
                            color: urlMa.containsMouse ? Pal.a(0.22) : Pal.a(0.10)
                            Text {
                                anchors.centerIn: parent
                                text: "󰌹"
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                            MouseArea {
                                id: urlMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.openTarget(preview.trim())
                            }
                        }

                        Rectangle {
                            visible: rowDelegate.cType === "file" || rowDelegate.cType === "image-file"
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 26
                            radius: 5
                            color: fileMa.containsMouse ? Pal.a(0.22) : Pal.a(0.10)
                            Text {
                                anchors.centerIn: parent
                                text: "󰈙"
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                            MouseArea {
                                id: fileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.openTarget(view.expandPath(preview.trim()))
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 26
                            radius: 5
                            color: pinMa.containsMouse ? Pal.a(0.22) : (isPinned ? Qt.rgba(1, 0, 0, 0.16) : Pal.a(0.08))
                            Text {
                                anchors.centerIn: parent
                                text: "󰤱"
                                color: isPinned ? view.sys.colCrit : (pinMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                            MouseArea {
                                id: pinMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.togglePin(preview)
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    anchors.rightMargin: rowDelegate.isSelected ? 110 : 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = rowDelegate.index
                    onClicked: view.copyAt(rowDelegate.index)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: list.model.count === 0
            text: view.query.length ? view.sys.tr("Nothing found") : view.sys.tr("Clipboard is empty")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }
}
