pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: ico

    property string code: ""
    property real size: 16
    property real gapRatio: 0.22
    property color color: "#ffffff"

    readonly property real dotSize: ico.size / (7 + 6 * ico.gapRatio)
    readonly property real gap: ico.dotSize * ico.gapRatio
    readonly property real pitch: ico.dotSize + ico.gap

    readonly property var shapes: ({
        "clear":       ["0000001000000", "0001011101000", "0000111110000", "0010111110100",
                        "0000111110000", "0001011101000", "0000001000000"],
        "clear_night": ["0000011110000", "0000111111000", "0001111000000", "0001110000000",
                        "0001111000000", "0000111111000", "0000011110000"],
        "few":         ["0000000001110", "0000000011111", "0011100111110", "0111111111111",
                        "1111111111111", "1111111111111", "0111111111110"],
        "few_night":   ["0000000011100", "0000000111100", "0011100111000", "0111111111111",
                        "1111111111111", "1111111111111", "0111111111110"],
        "cloud":       ["0000000011100", "0011100111110", "0111111111111", "1111111111111",
                        "1111111111111", "1111111111111", "0111111111110"],
        "rain":        ["0000000011100", "0011100111110", "0111111111111", "1111111111111",
                        "0111111111110", "0001001001000", "0010010010000"],
        "snow":        ["0000000011100", "0011100111110", "0111111111111", "1111111111111",
                        "0111111111110", "0001001001000", "0000100010000"],
        "storm":       ["0000000011100", "0011100111110", "0111111111111", "1111111111111",
                        "0111111111110", "0000011100000", "0000110000000"],
        "mist":        ["0000000000000", "0001111111000", "0000000000000", "0011111111100",
                        "0000000000000", "0001111111000", "0000000000000"]
    })

    readonly property string shapeName: {
        var s = String(ico.code);
        var k = s.slice(0, 2);
        var isNight = s.length >= 3 && s[2] === "n";
        return k === "01" ? (isNight ? "clear_night" : "clear")
             : k === "02" ? (isNight ? "few_night" : "few")
             : (k === "03" || k === "04") ? "cloud"
             : (k === "09" || k === "10") ? "rain"
             : k === "11" ? "storm"
             : k === "13" ? "snow"
             : k === "50" ? "mist"
             : "cloud";
    }

    readonly property var grid: ico.shapes[ico.shapeName]

    readonly property var cells: {
        var out = [];
        var g = ico.grid;
        if (!g) return out;
        for (var r = 0; r < g.length; r++)
            for (var c = 0; c < g[r].length; c++)
                if (g[r][c] === "1")
                    out.push({ x: c * ico.pitch, y: r * ico.pitch });
        return out;
    }

    implicitWidth: (ico.grid ? ico.grid[0].length : 13) * ico.pitch - ico.gap
    implicitHeight: 7 * ico.pitch - ico.gap

    Repeater {
        model: ico.cells

        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: ico.dotSize
            height: ico.dotSize
            radius: ico.dotSize / 2
            color: ico.color
        }
    }
}
