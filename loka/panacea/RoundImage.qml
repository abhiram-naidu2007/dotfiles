import QtQuick
import Quickshell.Io

Item {
    id: root
    property string source: ""
    property real radius: 8
    property int sourceWidth: 128
    readonly property bool ready: img.status === Image.Ready && img.source.toString().length > 0
    readonly property int px: Math.max(1, Math.round(Math.min(width, height)))

    function refresh() {
        prep.running = false;
        if (!root.source.length) { img.source = ""; return; }
        prep.command = ["loka-art", root.source, String(root.px), String(Math.round(root.radius))];
        prep.running = true;
    }
    onSourceChanged: refresh()
    onPxChanged: refresh()
    onRadiusChanged: refresh()
    Component.onCompleted: refresh()

    Process {
        id: prep
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                img.source = p.length ? "file://" + p : "";
            }
        }
    }

    Image {
        id: img
        anchors.centerIn: parent
        width: root.px
        height: root.px
        asynchronous: true
        cache: false
        smooth: false
    }
}
