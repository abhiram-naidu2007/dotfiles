import QtQuick

Timer {
    id: grab

    property Item target: null
    property int maxTries: 30

    property int tries: 0

    interval: 16
    repeat: true
    triggeredOnStart: true
    running: true

    onTriggered: {
        var t = grab.target;
        if (!t || t.activeFocus || grab.tries++ > grab.maxTries) {
            grab.stop();
            return;
        }
        if (t.visible) t.forceActiveFocus();
    }
}
