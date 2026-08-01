pragma Singleton
import QtQuick
import Quickshell

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
}
