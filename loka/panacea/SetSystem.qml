pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page

    property var sys

    property string osName: ""
    property string kernel: ""
    property string wm: ""
    property string cpuName: ""
    property string gpuName: ""
    property string host: ""
    property string uptime: ""

    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real load1: 0
    property int  procs: 0
    property real tempCpu: -1
    property real tempGpu: -1
    property real diskUsed: 0
    property real diskTotal: 0
    property real selfMb: 0

    function stepName(st) {
        return st === "download"      ? page.sys.tr("downloading")
             : st === "selfupdate"    ? page.sys.tr("updating the updater")
             : st === "backup"        ? page.sys.tr("saving settings")
             : st === "install"       ? page.sys.tr("installing")
             : st === "greeter"       ? page.sys.tr("login screen")
             : st === "restore"       ? page.sys.tr("restoring settings")
             : st === "voxtype_model" ? page.sys.tr("downloading voice model")
             : st === "restart"       ? page.sys.tr("restarting")
             : page.sys.tr("preparing");
    }

    property bool armed: false
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = false }

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: { pInfo.running = true; pLive.running = true; }

    Process {
        id: pInfo
        command: ["sh", "-c",
            "wm_ver=\"\"; " +
            "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then " +
            "  wm_ver=\"niri $(niri --version 2>/dev/null | awk '{print $2}')\"; " +
            "else " +
            "  wm_ver=\"${XDG_CURRENT_DESKTOP:-Hyprland} $(hyprctl version -j 2>/dev/null | sed -n 's/.*\\\"tag\\\": *\\\"\\([^\\\"]*\\)\\\".*/\\1/p')\"; " +
            "fi; " +
            "printf '%s\\n' \"$(. /etc/os-release 2>/dev/null; echo $PRETTY_NAME)\" " +
            "\"$(uname -r)\" \"$wm_ver\" " +
            "\"$(sed -n 's/^model name[ \\t]*: //p' /proc/cpuinfo | head -1)\" " +
            "\"$(lspci 2>/dev/null | sed -n 's/.*VGA compatible controller: //p' | head -1)\" " +
            "\"$(cat /etc/hostname 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.split("\n");
                page.osName  = (a[0] || "").trim();
                page.kernel  = (a[1] || "").trim();
                page.wm      = (a[2] || "").trim();
                page.cpuName = (a[3] || "").trim();
                page.gpuName = (a[4] || "").trim();
                page.host    = (a[5] || "").trim();
            }
        }
    }

    Process {
        id: pLive
        command: ["sh", "-c",
            "free -k | awk '/^Mem:/{printf \"%s %s|\", $3, $2} /^Swap:/{printf \"%s %s|\", $3, $2}'; " +
            "awk '{printf \"%s|\", $1}' /proc/loadavg; " +
            "ls -d /proc/[0-9]* | wc -l | tr -d '\\n'; printf '|'; " +
            "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in k10temp|coretemp|zenpower|cpu_thermal|acpitz_cpu) " +
            "cat $h/temp1_input 2>/dev/null | tr -d '\\n'; break;; esac; done; printf '|'; " +
            "gpu=''; for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in amdgpu|nouveau|radeon|i915|nvidia) " +
            "gpu=$(cat $h/temp1_input 2>/dev/null); break;; esac; done; " +
            "printf '%s|' \"$gpu\"; " +
            "df -k --output=used,size / | tail -1 | tr -s ' ' | sed 's/^ //' | tr -d '\\n'; printf '|'; " +
            "uptime -p | tr -d '\\n'; printf '|'; " +
            "awk '/VmRSS/{printf \"%s\", $2}' /proc/$PPID/status; printf '@'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var recs = text.split("@").filter(r => r.indexOf("|") > 0);
                if (!recs.length) return;
                var a = recs[recs.length - 1].trim().split("|");
                var mem = (a[0] || "").trim().split(/\s+/);
                var swp = (a[1] || "").trim().split(/\s+/);
                var dsk = (a[6] || "").trim().split(/\s+/);
                page.memUsed  = (+mem[0] || 0) / 1048576;
                page.memTotal = (+mem[1] || 0) / 1048576;
                page.swapUsed  = (+swp[0] || 0) / 1048576;
                page.swapTotal = (+swp[1] || 0) / 1048576;
                page.load1  = +a[2] || 0;
                page.procs  = +a[3] || 0;
                page.tempCpu = (+a[4] > 0) ? (+a[4] / 1000) : -1;
                page.tempGpu = (+a[5] > 0) ? (+a[5] / 1000) : -1;
                page.diskUsed  = (+dsk[0] || 0) / 1048576;
                page.diskTotal = (+dsk[1] || 0) / 1048576;
                page.uptime = (a[7] || "").trim();
                page.selfMb = (+a[8] || 0) / 1024;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: { pLive.running = false; pLive.running = true; }
    }

    Process { id: pOpen; property string url: ""; command: ["xdg-open", pOpen.url] }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Now") }

        component Meter: ColumnLayout {
            property string label: ""
            property string value: ""
            property real frac: 0
            property color tint: page.sys.colOn

            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: label
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
                Text {
                    text: value
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, frac))
                    height: parent.height
                    radius: parent.radius
                    color: tint
                    Behavior on width { NumberAnimation { duration: page.sys.animFade } }
                }
            }
        }

        Meter {
            label: page.sys.tr("System memory")
            value: page.memUsed.toFixed(1) + " / " + page.memTotal.toFixed(1) + " GiB"
            frac: page.memTotal > 0 ? page.memUsed / page.memTotal : 0
        }

        Meter {
            visible: page.swapTotal > 0
            label: page.sys.tr("Swap")
            value: page.swapUsed.toFixed(1) + " / " + page.swapTotal.toFixed(1) + " GiB"
            frac: page.swapTotal > 0 ? page.swapUsed / page.swapTotal : 0
        }

        Meter {
            label: page.sys.tr("Disk /")
            value: page.diskUsed.toFixed(0) + " / " + page.diskTotal.toFixed(0) + " GiB"
            frac: page.diskTotal > 0 ? page.diskUsed / page.diskTotal : 0
        }

        Meter {
            visible: page.tempCpu >= 0
            label: page.sys.tr("CPU temperature")
            value: page.tempCpu.toFixed(0) + " °C"
            frac: page.tempCpu / 100
            tint: page.tempCpu >= 80 ? page.sys.colCrit : page.sys.colOn
        }

        Meter {
            visible: page.tempGpu >= 0
            label: page.sys.tr("GPU temperature")
            value: page.tempGpu.toFixed(0) + " °C"
            frac: page.tempGpu / 100
            tint: page.tempGpu >= 85 ? page.sys.colCrit : page.sys.colOn
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Text {
                text: page.sys.tr("Load") + ": " + page.load1.toFixed(2)
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                text: "Panacea: " + page.selfMb.toFixed(0) + " MiB"
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                text: page.sys.tr("Processes") + ": " + page.procs
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Item { Layout.fillWidth: true }
        }
    }

    property var    browsers: []
    property string browserCur: ""
    Process {
        id: pBrowsers
        running: true
        command: ["sh", "-c", page.sys.scriptDir + "/browser.sh list; echo '--'; "
                              + page.sys.scriptDir + "/browser.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(text).split("--\n");
                var list = [];
                var lines = (parts[0] || "").split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|");
                    if (p.length >= 2) list.push({ id: p[0], text: p[1] });
                }
                page.browsers = list;
                page.browserCur = String(parts[1] || "").trim();
            }
        }
    }
    Process { id: pBrowserSet; onRunningChanged: if (!running) { pBrowsers.running = false; pBrowsers.running = true; } }

    SetCard {
        sys: page.sys
        visible: page.browsers.length > 0

        SetLabel { sys: page.sys; text: page.sys.tr("Default browser") }
        SetPick {
            sys: page.sys
            label: page.sys.tr("Open links in")
            options: page.browsers
            value: page.browserCur
            onPicked: id => {
                page.browserCur = id;
                pBrowserSet.command = ["sh", "-c", page.sys.scriptDir + "/browser.sh set \"$1\"", "_", id];
                pBrowserSet.running = true;
            }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Machine") }

        component Fact: RowLayout {
            id: rowlays
            property string k: ""
            property string v: ""

            Layout.fillWidth: true
            visible: v.length > 0
            spacing: 12

            Text {
                text: rowlays.k
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: rowlays.v
                color: page.sys.colFg
                elide: Text.ElideRight
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
        }

        Fact { k: page.sys.tr("System");    v: page.osName }
        Fact { k: page.sys.tr("Kernel");       v: page.kernel }
        Fact { k: page.sys.tr("Compositor"); v: page.wm }
        Fact { k: page.sys.tr("CPU");  v: page.cpuName }
        Fact { k: page.sys.tr("Videos");      v: page.gpuName }
        Fact { k: page.sys.tr("Hostname"); v: page.host }
        Fact { k: page.sys.tr("Uptime");     v: page.uptime }
        Fact { k: page.sys.tr("Shell");   v: "Panacea " + page.sys.version }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Reset") }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: page.armed
                      ? page.sys.tr("Press again and every setting returns to its factory value.")
                      : page.sys.tr("Return every setting to its factory value. Key bindings stay as they are.")
                color: page.armed ? page.sys.colCrit : page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            Rectangle {
                Layout.preferredWidth: Math.max(140, resetLabel.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                color: page.armed
                       ? Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b,
                                 resetMa.containsMouse ? 0.40 : 0.26)
                       : (resetMa.containsMouse
                          ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
                          : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06))
                border.width: page.armed ? 1 : 0
                border.color: page.sys.colCrit
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    id: resetLabel
                    anchors.centerIn: parent
                    text: page.armed ? page.sys.tr("Yes, reset") : page.sys.tr("Reset everything")
                    color: page.armed ? page.sys.colFg : page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }

                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.armed) { page.sys.resetCfg(); page.armed = false; }
                        else { page.armed = true; disarm.restart(); }
                    }
                }
            }
        }
    }

}
