pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado compartido de visibilidad entre la barra y sus paneles flotantes
// (dashboard, centro de notificaciones) — evita acoplar ventanas entre sí.
Singleton {
    id: root

    property bool dashboardOpen: false
    property bool notifCenterOpen: false

    function toggleDashboard() {
        root.notifCenterOpen = false;
        root.dashboardOpen = !root.dashboardOpen;
    }

    function toggleNotifCenter() {
        root.dashboardOpen = false;
        root.notifCenterOpen = !root.notifCenterOpen;
    }

    function closeAll() {
        root.dashboardOpen = false;
        root.notifCenterOpen = false;
    }

    // Permite disparar los toggles desde fuera de QuickShell (keybinds de
    // Hyprland) vía `quickshell ipc call uiState <función>`.
    IpcHandler {
        target: "uiState"

        function toggleDashboard(): void { root.toggleDashboard(); }
        function toggleNotifCenter(): void { root.toggleNotifCenter(); }
        function closeAll(): void { root.closeAll(); }
    }
}
