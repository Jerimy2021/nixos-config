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
    // Hito 004 follow-up 6: el menú de energía dejó de ser un dock flotante
    // en otra esquina — ahora ancla top-right igual que dashboard/
    // notifCenter (ver PowerMenu.qml/Bar.qml), así que comparte la misma
    // exclusión mutua que los otros dos.
    property bool powerMenuOpen: false
    // Hito 004 follow-up 13: popup standalone del selector de wallpapers
    // (ver WallpaperPickerPopup.qml) — reemplaza la pestaña "Wallpapers"
    // que vivía adentro del dashboard. Mismo patrón de exclusión mutua que
    // dashboard/notifCenter/powerMenu: los cuatro paneles top-anchored
    // nunca deberían verse superpuestos.
    property bool wallpaperPickerOpen: false
    // Pestaña activa del dashboard (Hito 004 follow-up 5: Dashboard/
    // Wallpapers/Media, ver Dashboard.qml + TabBar.qml). Vive acá y no como
    // property local del PanelWindow por el mismo motivo que el resto de
    // este singleton: un solo lugar para el estado de UI compartido, y de
    // paso queda testeable/operable por IPC igual que los demás toggles.
    property int dashboardTab: 0

    // Hito 004 follow-up 10: estado de hover combinado bar+card, usado por
    // el auto-cierre por salida de hover del dashboard (ver Dashboard.qml
    // `hoveringDashboard` + Timer de gracia). Viven acá y no como property
    // local de cada panel por el mismo motivo que dashboardTab: Bar.qml y
    // Dashboard.qml no se conocen entre sí directamente, así que necesitan
    // un lugar común. Asignación directa desde afuera (mismo patrón que
    // Theme.activeAccent en WorkspaceSync.qml), no funciones dedicadas —
    // es solo un booleano de hover, no una acción con lógica propia.
    property bool barHovered: false
    property bool dashboardCardHovered: false

    function toggleDashboard() {
        root.notifCenterOpen = false;
        root.powerMenuOpen = false;
        root.wallpaperPickerOpen = false;
        root.dashboardOpen = !root.dashboardOpen;
    }

    // Hito 004 follow-up 7: apertura por proximidad del reloj (ver
    // SystemCapsules.qml) — a diferencia de toggleDashboard(), esto solo
    // ABRE, nunca cierra, para no pelear con una apertura por teclado que
    // el hover del mouse no inició.
    function openDashboard() {
        root.notifCenterOpen = false;
        root.powerMenuOpen = false;
        root.wallpaperPickerOpen = false;
        root.dashboardOpen = true;
    }

    function setDashboardTab(index) {
        root.dashboardTab = index;
    }

    function toggleNotifCenter() {
        root.dashboardOpen = false;
        root.powerMenuOpen = false;
        root.wallpaperPickerOpen = false;
        root.notifCenterOpen = !root.notifCenterOpen;
    }

    // Hito 004 follow-up 6: el trigger del menú de energía ahora vive en la
    // barra igual que dashboard/notifCenter (ver PowerMenu.qml), así que
    // comparte la misma exclusión mutua — los tres paneles anclan en la
    // misma esquina top-right y nunca deberían verse superpuestos.
    function togglePowerMenu() {
        root.dashboardOpen = false;
        root.notifCenterOpen = false;
        root.wallpaperPickerOpen = false;
        root.powerMenuOpen = !root.powerMenuOpen;
    }

    // Hito 004 follow-up 13: ver WallpaperPickerPopup.qml — repuntado desde
    // SUPER+CTRL+W en keybinds.lua (antes abría el dashboard directo en la
    // pestaña Wallpapers, que ya no existe).
    function toggleWallpaperPicker() {
        root.dashboardOpen = false;
        root.notifCenterOpen = false;
        root.powerMenuOpen = false;
        root.wallpaperPickerOpen = !root.wallpaperPickerOpen;
    }

    function closeAll() {
        root.dashboardOpen = false;
        root.notifCenterOpen = false;
        root.powerMenuOpen = false;
        root.wallpaperPickerOpen = false;
    }

    // Permite disparar los toggles desde fuera de QuickShell (keybinds de
    // Hyprland) vía `quickshell ipc call uiState <función>`.
    IpcHandler {
        target: "uiState"

        function toggleDashboard(): void { root.toggleDashboard(); }
        function toggleNotifCenter(): void { root.toggleNotifCenter(); }
        function togglePowerMenu(): void { root.togglePowerMenu(); }
        function toggleWallpaperPicker(): void { root.toggleWallpaperPicker(); }
        function setDashboardTab(index: int): void { root.setDashboardTab(index); }
        function closeAll(): void { root.closeAll(); }
    }
}
