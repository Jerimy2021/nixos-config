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
    // Independiente de dashboard/notifCenter a propósito: el menú de
    // energía es un widget tipo "dock" flotante en otra esquina, no compite
    // por espacio ni exclusividad con los paneles top-right (ver PowerMenu.qml).
    property bool powerMenuOpen: false

    function toggleDashboard() {
        root.notifCenterOpen = false;
        root.dashboardOpen = !root.dashboardOpen;
    }

    function toggleNotifCenter() {
        root.dashboardOpen = false;
        root.notifCenterOpen = !root.notifCenterOpen;
    }

    function togglePowerMenu() {
        root.powerMenuOpen = !root.powerMenuOpen;
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
        function togglePowerMenu(): void { root.togglePowerMenu(); }
        function closeAll(): void { root.closeAll(); }
    }
}
