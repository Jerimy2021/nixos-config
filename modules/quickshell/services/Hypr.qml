pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Envoltorio fino sobre Quickshell.Hyprland — expone lo que la barra y el
// wallpaper-sync necesitan, y centraliza la sintaxis hl.dsp.* (Hyprland
// 0.55+ Lua, ver NIXOS_ARCHITECTURE_HITO_002.md §1.3) en un solo lugar.
Singleton {
    id: root

    readonly property var workspaces: Hyprland.workspaces
    readonly property var focused: Hyprland.focusedWorkspace
    readonly property int activeId: focused ? focused.id : 1

    function occupiedIds() {
        var ids = [];
        var values = workspaces ? workspaces.values : [];
        for (var i = 0; i < values.length; i++) {
            var w = values[i];
            var windows = w.lastIpcObject ? (w.lastIpcObject.windows || 0) : 0;
            if (windows > 0) ids.push(w.id);
        }
        return ids;
    }

    function focusWorkspace(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })");
    }

    function dispatch(expr) {
        Hyprland.dispatch(expr);
    }

    // Lista de clases de ventana actualmente abiertas (Hito 004 follow-up 4:
    // usado por AppLaunchers.qml para saber si Discord/Spotify ya están
    // corriendo). El módulo Quickshell.Hyprland no expone una lista de
    // clientes con clase por QML (su qmltypes de introspección viene vacío,
    // confirmado antes de escribir esto) — así que se pide directo a
    // `hyprctl clients -j`, mismo patrón que sidepad-toggle.sh ya usa desde
    // fuera de QML.
    property var runningClasses: []

    function hasClass(cls) {
        return root.runningClasses.indexOf(cls) !== -1;
    }

    function refreshClients() {
        clientsProc.running = true;
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var clients = JSON.parse(text);
                    root.runningClasses = clients.map(function (c) { return c.class; });
                } catch (e) {
                    root.runningClasses = [];
                }
            }
        }
    }

    Component.onCompleted: refreshClients()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n.indexOf("workspace") === 0 || n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "focusedmon") {
                Hyprland.refreshWorkspaces();
            }
            if (n === "openwindow" || n === "closewindow") {
                root.refreshClients();
            }
        }
    }
}
