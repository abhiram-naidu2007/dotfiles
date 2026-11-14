pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property string id: "meridian"

    readonly property bool meridian: id === "meridian"
    readonly property bool katha: id === "katha"
    readonly property bool sakuga: id === "sakuga"
    readonly property bool toon: id === "toon"

    readonly property string display: meridian ? "JetBrainsMono Nerd Font"
        : katha ? "Ramaraja"
        : sakuga ? "Inter Tight"
        : toon ? "Rounded Mplus 1c" : "Inter Tight"
    readonly property string text: meridian ? "JetBrainsMono Nerd Font"
        : katha ? "Anek Telugu"
        : sakuga ? "Inter Tight"
        : toon ? "Rounded Mplus 1c" : "Inter Tight"
    readonly property var textAxes: katha ? ({ "wdth": 82, "wght": 560 }) : ({})
    readonly property int textWeight: meridian ? Font.Medium : sakuga ? Font.Bold : toon ? Font.Bold : Font.DemiBold
    readonly property bool caps: meridian || sakuga
    readonly property real tracking: meridian ? 1.4 : sakuga ? 0.4 : 0

    readonly property int pillH: toon ? 32 : sakuga ? 28 : 30
    readonly property real radius: meridian ? 3 : sakuga ? 2 : toon ? 16 : 15
    readonly property real border: meridian ? 1 : toon ? 2 : sakuga ? 0 : 1
    readonly property real skew: sakuga ? -0.28 : 0
    readonly property bool lift: toon
    readonly property bool lacquer: katha

    readonly property int dur: meridian ? 110 : katha ? 360 : sakuga ? 170 : 300
    readonly property int easing: meridian ? Easing.Linear : katha ? Easing.InOutSine : sakuga ? Easing.OutBack : Easing.OutElastic
    readonly property real overshoot: sakuga ? 2.2 : 1.0

    readonly property var labels: meridian ? ["SYS", "MEM", "GPU"]
        : sakuga ? ["CPU", "RAM", "GPU"]
        : toon ? ["\u{f04c5}", "\u{f035b}", "\u{f08ae}"]
        : ["\u{f035b}", "\u{f061a}", "\u{f08ae}"]
    readonly property bool labelGlyphs: katha || toon

    readonly property string hp: meridian ? "blocks" : toon ? "hearts" : katha ? "lamp" : "bar"
    readonly property string workspace: meridian ? "dash" : katha ? "akshara" : sakuga ? "slash" : "bubble"
}
