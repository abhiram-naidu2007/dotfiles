pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

Singleton {
    id: hl
    readonly property bool usingLua: false
    property int rev: 0
    property var _tree: null
    property var _focusedWin: null
    signal rawEvent(var ev)

    readonly property var workspaces: {
        hl.rev;
        var src = I3.workspaces.values, out = [];
        for (var i = 0; i < src.length; i++) {
            var w = src[i];
            out.push({ id: w.number > 0 ? w.number : i + 1, name: w.name, monitor: w.monitor ? { name: w.monitor.name } : null, focused: w.focused, urgent: w.urgent, activate: w.activate });
        }
        return { values: out };
    }
    readonly property var focusedWorkspace: {
        hl.rev;
        var w = I3.focusedWorkspace;
        return w ? { id: w.number > 0 ? w.number : 1, name: w.name } : null;
    }
    readonly property var focusedMonitor: {
        hl.rev;
        var m = I3.focusedMonitor;
        if (!m) return null;
        var scr = null, ss = Quickshell.screens;
        for (var i = 0; i < ss.length; i++) if (ss[i].name === m.name) scr = ss[i];
        return { name: m.name, x: m.x, y: m.y, width: m.width, height: m.height, scale: 1, screen: scr,
                 activeWorkspace: hl.focusedWorkspace, lastIpcObject: { width: m.width, height: m.height, x: m.x, y: m.y } };
    }
    readonly property var toplevels: {
        hl.rev;
        var out = [];
        var t = hl._tree;
        if (!t) return { values: out };
        var walk = function (n, ws) {
            if (n.type === "workspace") ws = n;
            if (n.window && ws && ws.num > 0) {
                var r = n.rect;
                out.push({ address: "0x" + n.window.toString(16), title: n.name || "", wayland: null,
                           lastIpcObject: { at: [r.x, r.y], size: [r.width, r.height], workspace: { id: ws.num, name: ws.name },
                                            class: n.window_properties ? n.window_properties.class : "", initialClass: n.window_properties ? n.window_properties.class : "",
                                            title: n.name || "", hidden: false, fullscreen: n.fullscreen_mode, focused: n.focused } });
            }
            (n.nodes || []).concat(n.floating_nodes || []).forEach(function (c) { walk(c, ws); });
        };
        walk(t, null);
        return { values: out };
    }

    function refreshWorkspaces() { I3.refreshWorkspaces(); hl.rev++; }
    function refreshToplevels() { tree.running = false; tree.running = true; }

    function dispatch(cmd) {
        var s = String(cmd).trim();
        var m;
        if ((m = /^workspace\s+(-?\d+)$/.exec(s))) I3.dispatch("workspace number " + m[1]);
        else if ((m = /^workspace\s+(.+)$/.exec(s))) I3.dispatch("workspace " + m[1]);
        else if ((m = /^exec\s+(.+)$/.exec(s))) I3.dispatch("exec --no-startup-id " + m[1]);
        else if (s === "killactive") I3.dispatch("kill");
        else if (/^focuswindow\s+address:(0x[0-9a-f]+)/i.test(s)) I3.dispatch("[id=" + parseInt(/address:(0x[0-9a-f]+)/i.exec(s)[1]) + "] focus");
        else if ((m = /^movetoworkspace(silent)?\s+(\d+)/.exec(s))) I3.dispatch("move container to workspace number " + m[2]);
        else if (s === "exit") I3.dispatch("exit");
    }

    Process {
        id: tree
        command: ["i3-msg", "-t", "get_tree"]
        stdout: StdioCollector { onStreamFinished: { try { hl._tree = JSON.parse(this.text); hl.rev++; } catch (e) {} } }
    }

    Connections {
        target: I3
        function onRawEvent(ev) {
            hl.rev++;
            if (ev.type === "workspace") { hl.rawEvent({ name: "workspace", data: "" }); tree.running = false; tree.running = true; }
            else if (ev.type === "window") {
                var e = {};
                try { e = JSON.parse(ev.data); } catch (x) {}
                var map = { focus: "activewindow", title: "windowtitle", new: "openwindow", close: "closewindow", fullscreen_mode: "fullscreen", move: "movewindow" };
                hl.rawEvent({ name: map[e.change] || e.change, data: "" });
                if (e.change !== "title") { tree.running = false; tree.running = true; }
            } else if (ev.type === "mode") hl.rawEvent({ name: "submap", data: "" });
        }
    }
    Component.onCompleted: refreshToplevels()
}
