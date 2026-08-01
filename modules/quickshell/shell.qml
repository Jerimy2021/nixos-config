//@ pragma UseQApplication
import Quickshell
import qs.modules.bar

// Punto de entrada de QuickShell (Hito 004). Reemplaza waybar + swaync.
// Estructura modular: cada pieza (barra, dashboard, notificaciones) vive en
// su propio módulo bajo modules/, para que agregar widgets nuevos después
// no implique tocar este archivo salvo para una línea de instanciación.
ShellRoot {
    Bar {}
}
