import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Lanzadores de Discord y Spotify en la barra (Hito 004 follow-up 4): un
// click enfoca la ventana si ya está corriendo, o la lanza si no (lógica en
// el script app-toggle, ver scripts.nix — hyprctl dispatch con la sintaxis
// Lua de este fork, la sintaxis clásica focuswindow falla acá, probado en
// vivo). Íconos reales vía Quickshell.iconPath(), no glifos genéricos.
Row {
    id: root
    spacing: 8

    Capsule {
        // Nota: el nombre del ícono del .desktop de Discord es "discord" y
        // coincide con la clase real de ventana — no así Spotify (ver abajo).
        iconSource: Quickshell.iconPath("discord")
        active: Hypr.hasClass("discord")
        accent: Theme.activeAccent
        onClicked: discordToggle.running = true

        Process { id: discordToggle; command: ["app-toggle", "discord", "Discord"] }
    }

    Capsule {
        // Bug real encontrado en vivo: el .desktop de Spotify declara
        // StartupWMClass=spotify, pero la clase real de la ventana en
        // ejecución es "Spotify" (con mayúscula) — confirmado lanzando la
        // app de verdad y leyendo `hyprctl clients -j`, no asumido del
        // .desktop. El ícono SÍ es "spotify-client", no "spotify" (ese
        // nombre no resuelve, Quickshell.hasThemeIcon lo confirma en falso).
        iconSource: Quickshell.iconPath("spotify-client")
        active: Hypr.hasClass("Spotify")
        accent: Theme.activeAccent
        onClicked: spotifyToggle.running = true

        Process { id: spotifyToggle; command: ["app-toggle", "Spotify", "spotify"] }
    }
}
