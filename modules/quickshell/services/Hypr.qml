pragma Singleton
import QtQuick
import Quickshell
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

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n.indexOf("workspace") === 0 || n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "focusedmon") {
                Hyprland.refreshWorkspaces();
            }
        }
    }
}
