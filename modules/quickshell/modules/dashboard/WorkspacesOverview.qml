import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services

// Pestaña "Workspaces" del dashboard (Hito 004 follow-up 8): vista de solo
// lectura de qué apps corren en cada workspace, agrupadas vía
// Hypr.clientsByWorkspace() (ver Hypr.qml, extendido para esto según
// NIXOS_SHELL_VIDEO_ANALYSIS.md §7.4). Rango 1-10 confirmado en vivo contra
// modules/hyprland/core/keybinds.lua (bucle SUPER+1..9 más SUPER+0 mapeado
// a workspace 10) — no se asumió 1-9. El scratchpad especial "magic"
// (SUPER+S) es un concepto aparte (no navegación numerada) y queda fuera de
// esta grilla a propósito. Los pills de Workspaces.qml en la barra NO se
// tocan — esta pestaña es puramente informativa/aditiva, click opcional
// para enfocar (mismo Hypr.focusWorkspace() que ya usan los pills).
//
// Hito 004 follow-up 11: pase estético (pedido explícito: "más grande, más
// glow/color, más impacto visual") — íconos 20→24px, el workspace activo
// ahora proyecta glow real (MultiEffect, misma técnica que el resto del
// dashboard) en vez de solo un borde+fondo tenue.
//
// Hito 004 follow-up 12: cada app ahora muestra su título real al lado del
// ícono (antes solo el ícono, sin ninguna pista de CUÁL ventana era si había
// varias de la misma app en el mismo workspace). El dato ya venía en
// `hyprctl clients -j` sin usarse (campo "title", ver Hypr.qml
// clientsByWorkspace()) — esto cambió la fila de "Row horizontal de íconos"
// a una lista vertical de un renglón por ventana (icono+título no entran
// lado a lado repetidos sin volverse ilegibles a este ancho), así que la
// altura de cada bloque de workspace ahora es variable según cuántas
// ventanas tiene.
Column {
    id: root
    spacing: 8

    Repeater {
        model: 10

        delegate: Rectangle {
            id: wsRow
            required property int index
            readonly property int wsId: index + 1
            readonly property var clients: Hypr.clientsByWorkspace(wsId)
            readonly property bool isActive: Hypr.activeId === wsId

            width: parent.width
            height: content.implicitHeight + 20
            radius: 12
            color: isActive ? Theme.withAlpha(Theme.activeAccent, 0.16) : Theme.surfaceFaint
            border.width: isActive ? 1.4 : 1
            border.color: isActive ? Theme.activeAccent : Theme.surfaceBorder

            Behavior on height { NumberAnimation { duration: Theme.durFast } }
            Behavior on color { ColorAnimation { duration: Theme.durMed } }
            Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: wsRow.isActive
                shadowColor: Theme.activeAccent
                shadowBlur: 0.6
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }

            Column {
                id: content
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: String(wsRow.wsId)
                        color: wsRow.isActive ? Theme.activeAccent : Theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                        width: 18
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: Theme.durMed } }
                    }

                    Text {
                        visible: wsRow.clients.length === 0
                        text: "vacío"
                        color: Theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.italic: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Un renglón por ventana: ícono + título real, elidido si
                // no entra. anchors.left en vez de un Row envolvente para
                // que el título pueda usar todo el ancho restante sin
                // truncarse antes de tiempo por un spacing fijo.
                Repeater {
                    model: wsRow.clients

                    delegate: Item {
                        id: clientRow
                        required property var modelData

                        readonly property bool hasIcon: Quickshell.hasThemeIcon(modelData.class)

                        // x:30 alinea el ícono de cada ventana bajo el
                        // ícono de la fila de header (después del número
                        // de workspace) — el width tiene que descontar ese
                        // mismo offset, si no el borde derecho de este Item
                        // (y por lo tanto el punto de elide del Text de
                        // abajo) queda 30px más allá del `content` que lo
                        // contiene. `wsRow` no tiene clip:true propio, así
                        // que ese sobrante no se recortaba ahí — terminaba
                        // filtrando hasta el clip de la pestaña completa,
                        // muy más a la derecha (confirmado en vivo: el
                        // título se veía cortado seco contra el borde de
                        // TODA la tarjeta, no elidido con "…" contra su
                        // propia fila).
                        width: parent.width - x
                        height: 24
                        x: 30

                        Item {
                            id: appIcon
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                anchors.fill: parent
                                visible: clientRow.hasIcon
                                source: clientRow.hasIcon ? Quickshell.iconPath(clientRow.modelData.class) : ""
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !clientRow.hasIcon
                                radius: 5
                                color: Theme.withAlpha(Theme.activeAccent, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    text: (clientRow.modelData.class || "?").charAt(0).toUpperCase()
                                    color: Theme.activeAccent
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }
                        }

                        Text {
                            anchors.left: appIcon.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: clientRow.modelData.title
                            color: Theme.textPrimary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.focusWorkspace(wsRow.wsId)
            }
        }
    }
}
