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

    // Lista de clientes actualmente abiertos, cruda (Hito 004 follow-up 4:
    // usado por AppLaunchers.qml para saber si Discord/Spotify ya están
    // corriendo). El módulo Quickshell.Hyprland no expone una lista de
    // clientes con clase por QML (su qmltypes de introspección viene vacío,
    // confirmado antes de escribir esto) — así que se pide directo a
    // `hyprctl clients -j`, mismo patrón que sidepad-toggle.sh ya usa desde
    // fuera de QML.
    property var clients: []
    readonly property var runningClasses: root.clients.map(function (c) { return c.class; })

    function hasClass(cls) {
        return root.runningClasses.indexOf(cls) !== -1;
    }

    // Hito 004 follow-up 8: agrupa los clientes por workspace en vez de
    // aplanarlos a una lista global — usado por WorkspacesOverview.qml
    // (pestaña "Workspaces" del dashboard, ver NIXOS_SHELL_VIDEO_ANALYSIS.md
    // §7.4, que ya scopeaba esto contra caelestia-dots/shell).
    //
    // Hito 004 follow-up 11: antes devolvía solo las clases (strings) — el
    // título de cada ventana ya venía en `hyprctl clients -j` sin usarse
    // (campo "title", confirmado en vivo), y esta ronda pide mostrarlo junto
    // al ícono. Ahora devuelve {class, title} por cliente en vez de solo la
    // clase — WorkspacesOverview.qml sigue resolviendo el ícono con
    // Quickshell.iconPath(class) igual que antes, y ahora también puede
    // mostrar el título sin un segundo recorrido de `clients`.
    function clientsByWorkspace(wsId) {
        return root.clients
            .filter(function (c) { return c.workspace && c.workspace.id === wsId; })
            .map(function (c) { return { class: c.class, title: c.title || c.class }; });
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
                    root.clients = JSON.parse(text);
                } catch (e) {
                    root.clients = [];
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
            // Hito 004 follow-up 8: "movewindow" se agrega a este segundo
            // if — antes solo importaba para refrescar la lista global de
            // clases (que no cambia si una ventana cambia de workspace),
            // pero clientsByWorkspace() sí necesita saberlo para que
            // WorkspacesOverview.qml no muestre una ventana en el workspace
            // viejo después de moverla con SUPER+SHIFT+N.
            //
            // Hito 004 follow-up 11: "windowtitlev2" se agrega ahora que
            // WorkspacesOverview.qml muestra el título (antes solo la
            // clase, que no cambia en la vida de una ventana) — sin esto,
            // cambiar de pestaña en un browser/terminal con multiplexor
            // dejaría el título viejo pegado hasta el próximo open/close/
            // move de cualquier ventana.
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "windowtitlev2") {
                root.refreshClients();
            }
        }
    }
}
