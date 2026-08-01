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

    function wallpaperFor(id) {
        var n = wallpapers.length;
        return wallpapers[((id - 1) % n + n) % n];
    }

    function syncTo(id) {
        if (id === lastId) return;
        lastId = id;
        Theme.activeAccent = Theme.coreAccentFor(id);
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

    Component.onCompleted: syncTo(Hypr.activeId)
}
