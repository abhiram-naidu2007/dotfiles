import QtQuick

Item {
    id: glyph

    property string glyph: ""
    property color color: "#ffffff"
    property string fontFam: "monospace"
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    TextMetrics {
        id: tm
        font { family: glyph.fontFam; pixelSize: glyph.size }
        text: glyph.glyph
    }

    readonly property real baselineY: -tm.boundingRect.y
    readonly property real inkX: tm.tightBoundingRect.x + tm.tightBoundingRect.width / 2
    readonly property real inkY: baselineY + tm.tightBoundingRect.y
                                 + tm.tightBoundingRect.height / 2

    Text {
        text: glyph.glyph
        color: glyph.color
        font {
            family: glyph.fontFam; pixelSize: glyph.size
            hintingPreference: Font.PreferFullHinting
        }

        x: Math.round(glyph.width  / 2 - glyph.inkX)
        y: Math.round(glyph.height / 2 - glyph.inkY)

        Behavior on color { ColorAnimation { duration: 160 } }
    }
}
