import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services

// Pestaña "Workspaces" del dashboard (Hito 004 follow-up 8): vista de solo
// lectura de qué apps corren en cada workspace, agrupadas vía
// Hypr.classesByWorkspace() (ver Hypr.qml, extendido para esto según
// NIXOS_SHELL_VIDEO_ANALYSIS.md §7.4). Rango 1-10 confirmado en vivo contra
// modules/hyprland/core/keybinds.lua (bucle SUPER+1..9 más SUPER+0 mapeado
// a workspace 10) — no se asumió 1-9. El scratchpad especial "magic"
// (SUPER+S) es un concepto aparte (no navegación numerada) y queda fuera de
// esta grilla a propósito. Los pills de Workspaces.qml en la barra NO se
// tocan — esta pestaña es puramente informativa/aditiva, click opcional
// para enfocar (mismo Hypr.focusWorkspace() que ya usan los pills).
//
// Hito 004 follow-up 11: pase estético (pedido explícito: "más grande, más
// glow/color, más impacto visual") — filas 40→48px, íconos 20→24px, el
// workspace activo ahora proyecta glow real (MultiEffect, misma técnica que
// el resto del dashboard) en vez de solo un borde+fondo tenue.
Column {
    id: root
    spacing: 8

    Repeater {
        model: 10

        delegate: Rectangle {
            id: wsRow
            required property int index
            readonly property int wsId: index + 1
            readonly property var classes: Hypr.classesByWorkspace(wsId)
            readonly property bool isActive: Hypr.activeId === wsId

            width: parent.width
            height: 48
            radius: 12
            color: isActive ? Theme.withAlpha(Theme.activeAccent, 0.16) : Theme.surfaceFaint
            border.width: isActive ? 1.4 : 1
            border.color: isActive ? Theme.activeAccent : Theme.surfaceBorder

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

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
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

                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: wsRow.classes

                        delegate: Item {
                            id: appIcon
                            required property string modelData

                            readonly property bool hasIcon: Quickshell.hasThemeIcon(modelData)

                            width: 24
                            height: 24

                            IconImage {
                                anchors.fill: parent
                                visible: appIcon.hasIcon
                                source: appIcon.hasIcon ? Quickshell.iconPath(appIcon.modelData) : ""
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !appIcon.hasIcon
                                radius: 5
                                color: Theme.withAlpha(Theme.activeAccent, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    text: (appIcon.modelData || "?").charAt(0).toUpperCase()
                                    color: Theme.activeAccent
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: wsRow.classes.length === 0
                    text: "vacío"
                    color: Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.italic: true
                    anchors.verticalCenter: parent.verticalCenter
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
