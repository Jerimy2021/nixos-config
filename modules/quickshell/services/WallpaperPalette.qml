pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Paleta derivada de matugen, cacheada por wallpaper (Hito 004 follow-up).
// workspace-wallpaper (scripts.nix) corre matugen una sola vez por
// wallpaper y escribe ~/.cache/quickshell/palette.json; este archivo lo
// lee y lo vigila, así el acento de la barra se actualiza solo apenas el
// color esté listo, sin bloquear el cambio de workspace.
//
// Nombre "WallpaperPalette", no "Palette": QtQuick ya expone un tipo
// built-in llamado `Palette` (esquemas de color de Quick Controls) que
// gana la resolución de nombre sobre un singleton `qs.services` con el
// mismo nombre — colisión real encontrada en vivo (ver commit).
Singleton {
    id: root

    readonly property string cachePath: "/home/jerimy/.cache/quickshell/palette.json"
    property var cache: ({})

    // Truco de coerción string -> color: una property declarada `color`
    // convierte el hex automáticamente al asignarla, lo que habilita los
    // accesores .hslHue/.hslSaturation/.hslLightness que un `var` JS suelto
    // no tiene.
    property color _scratch: "#000000"

    // matugen (Material You) tiende a elegir tonos pastel/desaturados —
    // exactamente lo que este sistema prohíbe (ver Hito 001 §0: "Prohibidos
    // temas pastel o de baja saturación"). Se conserva el HUE real de la
    // imagen (ahí está la variedad "matugen-driven" por wallpaper) pero se
    // fuerza saturación/luminosidad a un rango vívido apto para glow sobre
    // fondo oscuro.
    function vividize(hex) {
        root._scratch = hex;
        var h = root._scratch.hslHue;
        var s = Math.max(root._scratch.hslSaturation, 0.55);
        var l = Math.min(Math.max(root._scratch.hslLightness, 0.55), 0.72);
        return Qt.hsla(h, s, l, 1.0);
    }

    // Devuelve el acento derivado para ese wallpaper, o undefined si
    // todavía no está cacheado (matugen corriendo en background, o nunca
    // corrió para esa ruta).
    function colorFor(wallpaperPath) {
        var hex = root.cache[wallpaperPath];
        return hex ? root.vividize(hex) : undefined;
    }

    function ensureCacheFile() {
        ensureProc.running = true;
    }

    Process {
        id: ensureProc
        command: ["bash", "-c", "mkdir -p \"$HOME/.cache/quickshell\"; [ -f \"$HOME/.cache/quickshell/palette.json\" ] || echo '{}' > \"$HOME/.cache/quickshell/palette.json\""]
    }

    Component.onCompleted: ensureCacheFile()

    FileView {
        id: file
        path: root.cachePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.cache = JSON.parse(text());
            } catch (e) {
                root.cache = {};
            }
        }
        onLoadFailed: root.cache = {}
    }
}
