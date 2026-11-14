pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page

    property var sys

    property var mons: []

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: { pMons.running = true; page.sys.brightRefresh(false); }

    function brightOf(name) {
        var l = page.sys.brightList || [];
        for (var i = 0; i < l.length; i++)
            if (l[i].name === name) return l[i];
        if (l.length === 1 && page.sys.brightBackend === "backlight") return l[0];
        return null;
    }

    Process {
        id: pMons
        command: ["sh", "-c", "hyprctl -j monitors all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = JSON.parse(text.slice(text.lastIndexOf("[{")));
                    page.mons = raw.map(m => ({
                        name: m.name,
                        desc: m.description || "",
                        w: m.width, h: m.height,
                        rr: m.refreshRate,
                        scale: m.scale,
                        transform: m.transform,
                        vrr: !!m.vrr,
                        x: m.x, y: m.y,
                        modes: m.availableModes || []
                    }));
                } catch (e) {
                    page.mons = [];
                }
            }
        }
    }

    function apply(m, over) {
        page.sys.monApply(m.name, {
            w:  over.w  !== undefined ? over.w  : m.w,
            h:  over.h  !== undefined ? over.h  : m.h,
            rr: over.rr !== undefined ? over.rr : m.rr,
            scale: over.scale !== undefined ? over.scale : m.scale,
            transform: over.transform !== undefined ? over.transform : m.transform,
            vrr: m.vrr,
            pos: over.pos !== undefined ? over.pos : page.placeOf(m)
        });
        reload.restart();
    }

    Timer {
        id: reload
        interval: 700
        onTriggered: { pMons.running = false; pMons.running = true; }
    }

    function placeOf(m) {
        var base = page.mons.length ? page.mons[0] : null;
        if (!base || base.name === m.name) return "auto";
        if (m.x >= base.x + base.w) return "auto-right";
        if (m.x + m.w <= base.x)    return "auto-left";
        if (m.y >= base.y + base.h) return "auto-down";
        if (m.y + m.h <= base.y)    return "auto-up";
        return "auto";
    }

    function resList(m) {
        var seen = {}, out = [];
        (m.modes || []).forEach(s => {
            var r = s.split("@")[0];
            if (!seen[r]) { seen[r] = true; out.push(r); }
        });
        if (!out.length) out.push(m.w + "x" + m.h);
        return out;
    }
    function rrList(m, res) {
        var out = [];
        (m.modes || []).forEach(s => {
            var p = s.split("@");
            if (p[0] !== res) return;
            var hz = parseFloat(p[1]);
            if (out.indexOf(hz) < 0) out.push(hz);
        });
        if (!out.length) out.push(m.rr);
        return out.sort((a, b) => b - a);
    }

    SetCard {
        sys: page.sys
        visible: page.mons.length > 1

        SetLabel {
            sys: page.sys
            text: page.sys.tr("Dynamic island")
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Show on screen")
            options: [{ id: "auto", text: page.sys.tr("Follow focus") }].concat(
                page.mons.map(m => ({
                    id: m.name,
                    text: m.name + (m.desc.length ? " · " + m.desc : "")
                })))
            value: page.sys.cfg.pillScreen
            onPicked: id => { page.sys.cfg.pillScreen = id; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("“Follow focus” moves the island to whichever screen you are working on.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: page.mons.length === 0
        text: page.sys.tr("Screens cannot be read: hyprctl did not answer.")
        color: page.sys.colMuted
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
    }

    Repeater {
        model: page.mons

        SetCard {
            id: card
            required property var modelData
            required property int index
            readonly property string res: card.modelData.w + "x" + card.modelData.h

            sys: page.sys

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: card.modelData.name
                        color: page.sys.colFg
                        font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: card.modelData.desc.length > 0
                        text: card.modelData.desc
                        color: page.sys.colMuted
                        elide: Text.ElideRight
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                    }
                }

                Text {
                    text: card.res + " · " + Number(card.modelData.rr).toFixed(0) + " Hz"
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }
            }

            SetPick {
                sys: page.sys
                label: page.sys.tr("Resolution")
                options: page.resList(card.modelData)
                value: card.res
                onPicked: id => {
                    var wh = id.split("x");
                    var hz = page.rrList(card.modelData, id)[0];
                    page.apply(card.modelData, { w: +wh[0], h: +wh[1], rr: hz });
                }
            }

            SetPick {
                sys: page.sys
                label: page.sys.tr("Refresh rate")
                options: page.rrList(card.modelData, card.res).map(hz => ({
                    id: String(hz), text: hz.toFixed(2) + " Hz"
                }))
                value: String(page.rrList(card.modelData, card.res)
                              .find(hz => Math.abs(hz - card.modelData.rr) < 0.6)
                              || card.modelData.rr)
                onPicked: id => page.apply(card.modelData, { rr: parseFloat(id) })
            }

            Text {
                Layout.fillWidth: true
                visible: (card.modelData.modes || []).length === 0
                text: page.sys.tr("The monitor reported no modes. Usually the graphics driver is missing.")
                color: page.sys.colCrit
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            SetSelect {
                sys: page.sys
                visible: page.mons.length > 1 && card.index > 0
                label: page.sys.tr("Placement") + (page.mons.length > 1
                       ? " — " + page.sys.tr("relative to") + " " + page.mons[0].name : "")
                options: [
                    { id: "auto-right", text: page.sys.tr("Right of") },
                    { id: "auto-left",  text: page.sys.tr("Left of") },
                    { id: "auto-up",    text: page.sys.tr("Above") },
                    { id: "auto-down",  text: page.sys.tr("Below") }
                ]
                value: page.placeOf(card.modelData)
                onPicked: id => page.apply(card.modelData, { pos: id })
            }

            SetSlider {
                id: brightSl
                readonly property var b: page.brightOf(card.modelData.name)
                sys: page.sys
                visible: brightSl.b !== null
                label: page.sys.tr("Brightness")
                from: 1; to: 100; step: 1
                value: brightSl.b ? brightSl.b.pct : 0
                suffix: "%"
                onMoved: v => { if (brightSl.b) page.sys.brightSet(brightSl.b.id, v); }
            }

            Text {
                Layout.fillWidth: true
                visible: page.brightOf(card.modelData.name) === null
                         && !page.sys.batteryPresent
                text: !page.sys.ddcutilPresent
                      ? page.sys.tr("Monitor brightness needs ddcutil, which is not installed. Install ddcutil and the slider appears here.")
                      : page.sys.tr("The monitor does not answer DDC/CI brightness requests. Turn on DDC/CI in its menu.")
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            SetSlider {
                sys: page.sys
                visible: card.index === 0 && Compositor.hasVibrance
                label: page.sys.tr("Digital vibrance")
                from: 0; to: 100; step: 5
                value: page.sys.cfg.vibrance
                suffix: "%"
                onMoved: v => page.sys.applyVibrance(v)
            }

            SetSlider {
                sys: page.sys
                visible: !Compositor.isI3
                label: page.sys.tr("Scale")
                from: 1; to: 3; step: 0.05
                decimals: 2
                value: card.modelData.scale
                suffix: "×"
                onMoved: v => page.apply(card.modelData, { scale: v })
            }

            SetSelect {
                sys: page.sys
                label: page.sys.tr("Rotation")
                options: [
                    { id: "0", text: "0°" },
                    { id: "1", text: "90°" },
                    { id: "2", text: "180°" },
                    { id: "3", text: "270°" }
                ]
                value: String(card.modelData.transform)
                onPicked: id => page.apply(card.modelData, { transform: +id })
            }

        }
    }

    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: page.sys.tr("Detect displays")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1 }
                }
                Text {
                    Layout.fillWidth: true
                    text: page.sys.tr("Re-read the list of connected monitors.")
                    color: page.sys.colMuted
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            Rectangle {
                Layout.preferredWidth: 118
                Layout.preferredHeight: 32
                radius: 10
                color: detectMa.containsMouse
                       ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.28)
                       : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: page.sys.tr("Refresh")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }
                MouseArea {
                    id: detectMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { pMons.running = false; pMons.running = true; }
                }
            }
        }
    }
}
