import QtQuick
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
        implicitHeight: 38
        exclusiveZone: implicitHeight
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.surface

            // Hito 004 follow-up 4: antes solo la línea de abajo cargaba el
            // acento — el resto de la barra era Theme.surface plano, así que
            // el cambio de workspace/wallpaper apenas se notaba fuera de esa
            // línea de 2px. Esta capa tiñe TODA la superficie con el acento
            // activo a baja opacidad, superpuesta sobre el vidrio oscuro (no
            // en vez de él) — sigue siendo "superficie oscura con tinte", no
            // "barra de color", y no toca la transparencia/blur del
            // Rectangle base ni del layer_rule de window-rules.lua.
            Rectangle {
                anchors.fill: parent
                color: Theme.activeAccent
                opacity: 0.09

                Behavior on color { ColorAnimation { duration: Theme.durSlow } }
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

                SystemCapsules {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
