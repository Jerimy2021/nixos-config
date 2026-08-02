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
    // Pestaña activa del dashboard (Hito 004 follow-up 5: Dashboard/
    // Wallpapers/Media, ver Dashboard.qml + TabBar.qml). Vive acá y no como
    // property local del PanelWindow por el mismo motivo que el resto de
    // este singleton: un solo lugar para el estado de UI compartido, y de
    // paso queda testeable/operable por IPC igual que los demás toggles.
    property int dashboardTab: 0

    function toggleDashboard() {
        root.notifCenterOpen = false;
        root.powerMenuOpen = false;
        root.dashboardOpen = !root.dashboardOpen;
    }

    function setDashboardTab(index) {
        root.dashboardTab = index;
    }

    function toggleNotifCenter() {
        root.dashboardOpen = false;
        root.powerMenuOpen = false;
        root.notifCenterOpen = !root.notifCenterOpen;
    }

    // Hito 004 follow-up 6: el trigger del menú de energía ahora vive en la
    // barra igual que dashboard/notifCenter (ver PowerMenu.qml), así que
    // comparte la misma exclusión mutua — los tres paneles anclan en la
    // misma esquina top-right y nunca deberían verse superpuestos.
    function togglePowerMenu() {
        root.dashboardOpen = false;
        root.notifCenterOpen = false;
        root.powerMenuOpen = !root.powerMenuOpen;
    }

    function closeAll() {
        root.dashboardOpen = false;
        root.notifCenterOpen = false;
        root.powerMenuOpen = false;
    }

    // Permite disparar los toggles desde fuera de QuickShell (keybinds de
    // Hyprland) vía `quickshell ipc call uiState <función>`.
    IpcHandler {
        target: "uiState"

        function toggleDashboard(): void { root.toggleDashboard(); }
        function toggleNotifCenter(): void { root.toggleNotifCenter(); }
        function togglePowerMenu(): void { root.togglePowerMenu(); }
        function setDashboardTab(index: int): void { root.setDashboardTab(index); }
        function closeAll(): void { root.closeAll(); }
    }
}
