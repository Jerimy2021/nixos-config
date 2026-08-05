import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services
import qs.modules.bar

// Barra principal (Hito 004 / Item 1). Una instancia por pantalla vía
// Variants — hoy es solo eDP-1, pero así no hay que tocar nada si se
// conecta un externo (ver modules/hyprland/core/monitors.lua, fallback ya
// declarado ahí).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar
        required property var modelData
        screen: modelData

        anchors {
            left: true
            right: true
            top: true
        }
        // Hito 004 follow-up 6 (ver NIXOS_SHELL_VIDEO_ANALYSIS.md §7.6): la
        // ventana es más alta que la barra visual (44 vs 38) a propósito —
        // esos 6px extra son el margen donde puede "sangrar" la sombra de
        // elevación sin que la recorte el propio buffer de la superficie
        // Wayland (un layer-shell surface se recorta exacto a su tamaño, no
        // hay overflow visual posible fuera de sus propios píxeles). La
        // reserva real de espacio para el tiling de ventanas (exclusiveZone)
        // sigue siendo 38 — la sombra se dibuja sobre lo que sea que haya
        // debajo, no reserva espacio propio.
        implicitHeight: 44
        exclusiveZone: 38
        color: "transparent"

        Rectangle {
            id: surface
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 38

            // Antes: Theme.surface plano + una capa Rectangle semitransparente
            // encima con el acento a 9% de opacidad. Investigar el proyecto de
            // referencia real (caelestia-dots/shell, services/Colours.qml)
            // reveló que su "vidrio" no es transparencia/blur — es un tinte
            // horneado en el color de superficie mismo (opaco), con la
            // separación "flotante" lograda por sombra de elevación, no por
            // blur. Este color ya es el resultado del tinte — no hay capa
            // extra encima (ver Theme.tintSurface()).
            color: Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }

            // Hito 004 follow-up 10: trigger de apertura del dashboard por
            // hover, movido acá desde la cápsula del reloj (ver
            // SystemCapsules.qml) — cubre TODA la barra en vez de un centro
            // arbitrario. Se probaron ambas en vivo: una franja central no
            // tiene ningún elemento visual que la sugiera (workspaces a la
            // izquierda, cápsulas a la derecha, el medio está vacío), así
            // que hoverearla se sentía como encontrar un punto ciego. La
            // barra entera sí es un target obvio — es la superficie que ya
            // se ve como "la barra", no hace falta adivinar dónde. Reusa
            // HoverHandler, mismo mecanismo que ya usa Capsule.qml
            // (proximityHover) en vez de inventar un tercer sistema de hover.
            // `UiState.barHovered` alimenta además el auto-cierre por salida
            // de hover del dashboard (ver Dashboard.qml).
            HoverHandler {
                id: barHover
                target: surface
                onHoveredChanged: {
                    UiState.barHovered = hovered;
                    if (hovered) UiState.openDashboard();
                }
            }

            // Sombra de elevación real (RectangularShadow-equivalente vía
            // MultiEffect, ambos tipos estándar de QtQuick.Effects, sin
            // dependencia del plugin nativo de Caelestia — confirmado en
            // NIXOS_SHELL_VIDEO_ANALYSIS.md §7.6/§7.7). Es la técnica real
            // que separa visualmente la bar del escritorio en el proyecto de
            // referencia, no un blur de fondo.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.5
                shadowVerticalOffset: 3
                shadowHorizontalOffset: 0
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                color: Theme.activeAccent
                opacity: 0.85

                Behavior on color { ColorAnimation { duration: Theme.durSlow } }
            }

            Workspaces {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Capsule {
                    icon: "󰂚"
                    value: NotifServer.history.length > 0 ? String(NotifServer.history.length) : ""
                    active: NotifServer.popups.length > 0
                    accent: Theme.neonMagenta
                    onClicked: UiState.toggleNotifCenter()
                }

                AppLaunchers {
                    anchors.verticalCenter: parent.verticalCenter
                }

                SystemCapsules {
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Hito 004 follow-up 6: trigger del menú de energía movido
                // acá desde un dock flotante propio (ver
                // NIXOS_SHELL_VIDEO_ANALYSIS.md §7.1) — icono dedicado en la
                // barra, no anidado en ningún dropdown, igual que pide el
                // requisito original. El panel (PowerMenu.qml) se despliega
                // como dropdown top-right, mismo patrón que Dashboard/
                // NotificationCenter.
                Capsule {
                    icon: "󰐥"
                    accent: Theme.danger
                    active: UiState.powerMenuOpen
                    onClicked: UiState.togglePowerMenu()
                }
            }
        }
    }
}
