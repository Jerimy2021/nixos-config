pragma Singleton
import QtQuick
import Quickshell

// Paleta única del sistema (Hyprland borders, rofi, Neovim) — reutilizada aquí
// para que QuickShell se sienta parte del mismo escritorio, no una pieza ajena.
Singleton {
    id: root

    // --- Acentos núcleo (bordes activos de Hyprland, superficies base) ---
    readonly property color lavender: "#cba6f7"
    readonly property color blue: "#89b4fa"
    readonly property color pink: "#f5c2e7"
    readonly property var coreAccents: [lavender, blue, pink]

    // --- Acentos neón (solo superficies elevadas: dashboard, notificaciones) ---
    readonly property color neonMagenta: "#ff2a6d"
    readonly property color neonCyan: "#05d9e8"
    readonly property color neonGreen: "#00ff9f"
    readonly property var neonAccents: [neonMagenta, neonCyan, neonGreen]

    // --- Superficies base (glassmorphism, casi negro) ---
    // Nota: QML interpreta hex de 8 dígitos como #AARRGGBB, no #RRGGBBAA —
    // se usa Qt.rgba(r, g, b, a) en todas partes para evitar esa ambigüedad.
    readonly property color surface: Qt.rgba(0.039, 0.039, 0.071, 0.87)
    readonly property color surfaceElevated: Qt.rgba(0.051, 0.051, 0.086, 0.91)
    readonly property color surfaceHover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color surfaceFaint: Qt.rgba(1, 1, 1, 0.03)
    readonly property color surfaceBorder: Qt.rgba(1, 1, 1, 0.10)
    readonly property color textPrimary: "#f1e6ff"
    readonly property color textMuted: "#b8aecf"

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Hito 004 follow-up 6 (ver NIXOS_SHELL_VIDEO_ANALYSIS.md §7.6): mezcla
    // el hue/saturación de `accent` hacia `base` en espacio HSL, preservando
    // la luminosidad (y el alpha) de `base` — así el resultado sigue siendo
    // una "superficie oscura", nunca "una barra de color". Reemplaza la capa
    // de opacidad plana que usábamos antes (Rectangle semitransparente
    // encima) por un tinte real horneado en el color de superficie mismo,
    // que es la técnica que encontramos en el proyecto de referencia real
    // (services/Colours.qml de caelestia-dots/shell, función alterColour())
    // — sin su término wallLuminance, que depende del plugin nativo
    // ImageAnalyser que decidimos no adoptar (ver §7.5/§C).
    function tintSurface(base, accent, strength) {
        var s = Math.max(0, Math.min(1, strength));
        var mixed = Qt.hsla(accent.hslHue, Math.min(1, accent.hslSaturation * s + 0.05), base.hslLightness, 1);
        return Qt.rgba(mixed.r, mixed.g, mixed.b, base.a);
    }

    readonly property color danger: "#f38ba8"
    readonly property color warn: "#f9e2af"
    readonly property color ok: "#a6e3a1"

    function coreAccentFor(id) {
        var n = coreAccents.length;
        return coreAccents[((id - 1) % n + n) % n];
    }

    function neonAccentFor(id) {
        var n = neonAccents.length;
        return neonAccents[((id - 1) % n + n) % n];
    }

    // Acento activo del bar/glow, sincronizado por workspace (ver WorkspaceSync.qml)
    property color activeAccent: lavender

    // --- Curvas de easing compartidas para que toda animación se sienta igual ---
    readonly property int durFast: 140
    readonly property int durMed: 240
    readonly property int durSlow: 420
    readonly property int easeOutCubic: Easing.OutCubic
    readonly property int easeOutBack: Easing.OutBack
    readonly property int easeInOutQuad: Easing.InOutQuad
}
