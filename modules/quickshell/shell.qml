//@ pragma UseQApplication
import QtQml
import Quickshell
import qs.services
import qs.modules.bar
import qs.modules.dashboard
import qs.modules.notifications
import qs.modules.powermenu
import qs.modules.hdmi
import qs.modules.network

// Punto de entrada de QuickShell (Hito 004). Reemplaza waybar + swaync.
// Estructura modular: cada pieza (barra, dashboard, notificaciones) vive en
// su propio módulo bajo modules/, para que agregar widgets nuevos después
// no implique tocar este archivo salvo para una línea de instanciación.
ShellRoot {
    // Recarga en caliente al guardar cualquier .qml del árbol — sin esto
    // cada cambio de estilo/lógica requeriría matar y relanzar `qs` a mano.
    settings.watchFiles: true

    Bar {}
    Dashboard {}
    WallpaperPickerPopup {}
    NotificationPopups {}
    NotificationCenter {}
    PowerMenu {}
    HdmiMenu {}
    NetworkMenu {}

    // Los singletons pragma Singleton de QML se crean perezosamente en el
    // primer acceso — este QtObject fuerza a WorkspaceSync a existir desde
    // el arranque, para que el hook de wallpaper+acento por workspace
    // quede activo sin depender de que algún widget lo use.
    QtObject {
        Component.onCompleted: WorkspaceSync.syncTo(Hypr.activeId)
    }
}
