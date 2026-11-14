pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property color fg: "#ffffff"
    property color bg: "#000000"
    function a(x) { return Qt.rgba(fg.r, fg.g, fg.b, x); }
    function b(x) { return Qt.rgba(bg.r, bg.g, bg.b, x); }
}
