pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Hito 004 / Item 2: al cambiar de workspace, dispara una transición de
// wallpaper (awww) y sincroniza el acento/glow de la barra. Se apoya en el
// evento nativo de Hyprland (Hypr.activeId, alimentado por hl.on/rawEvent),
// no en un mecanismo paralelo — ver directriz del brief de Hito 004.
Singleton {
    id: root

    readonly property var wallpapers: [
        "/home/jerimy/Pictures/Wallpapers/default.jpg",
        "/home/jerimy/Pictures/Wallpapers/mountain.jpg",
        "/home/jerimy/Pictures/Wallpapers/kaneki.png",
        "/home/jerimy/Pictures/Wallpapers/tokyo-ghoul.png",
        "/home/jerimy/Pictures/Wallpapers/orange-mountain.jpg",
        "/home/jerimy/Pictures/Wallpapers/kaneki2.png",
        "/home/jerimy/Pictures/Wallpapers/tokyoGoulRe.png",
        "/home/jerimy/Pictures/Wallpapers/kaneki3.png",
        "/home/jerimy/Pictures/Wallpapers/Nocturne-of-Steel-and-Glass.jpg"
    ]

    property int lastId: -1

    // Elecciones manuales desde el picker del dashboard (Hito 004 follow-up
    // 3): mapa workspace-id -> ruta, en memoria (se resetea con el proceso
    // qs, no se persiste a disco — no se pidió sobrevivir un restart). Sin
    // esto, un pick manual se vería un instante y luego "revertiría" al
    // ciclo fijo apenas se cambiara de workspace y se volviera.
    property var overrides: ({})

    function wallpaperFor(id) {
        if (root.overrides[id]) return root.overrides[id];
        var n = wallpapers.length;
        return wallpapers[((id - 1) % n + n) % n];
    }

    // Llamado por WallpaperPicker.qml. Reusa syncTo() en vez de disparar su
    // propio Process para no duplicar la ruta de aplicar+cachear paleta.
    function setWallpaperForCurrent(path) {
        var id = Hypr.activeId;
        var copy = Object.assign({}, root.overrides);
        copy[id] = path;
        root.overrides = copy;
        // syncTo() no hace nada si id === lastId (ya "sincronizado"); acá el
        // id no cambió pero SÍ cambió a qué wallpaper mapea, así que hay que
        // forzar que pase el guard.
        root.lastId = -1;
        root.syncTo(id);
    }

    // Acento matugen-derivado si ya está cacheado para este wallpaper
    // (WallpaperPalette.qml), si no el ciclo núcleo fijo — nunca bloquea el cambio
    // de workspace esperando a matugen.
    function applyAccent(id) {
        var derived = WallpaperPalette.colorFor(wallpaperFor(id));
        Theme.activeAccent = derived !== undefined ? derived : Theme.coreAccentFor(id);
    }

    function syncTo(id) {
        root.applyAccent(id);
        if (id === lastId) return;
        lastId = id;
        proc.command = ["workspace-wallpaper", wallpaperFor(id)];
        proc.running = true;
    }

    Process {
        id: proc
    }

    Connections {
        target: Hypr
        function onActiveIdChanged() { root.syncTo(Hypr.activeId); }
    }

    // Si matugen termina en background *después* de que ya estemos parados
    // en ese workspace (primer visit), esto "sube de calidad" el acento del
    // hardcoded al derivado real sin que el usuario tenga que volver a
    // cambiar de workspace.
    Connections {
        target: WallpaperPalette
        function onCacheChanged() { root.applyAccent(Hypr.activeId); }
    }

    Component.onCompleted: syncTo(Hypr.activeId)
}
