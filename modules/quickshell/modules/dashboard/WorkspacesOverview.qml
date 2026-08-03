import QtQuick
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
Column {
    id: root
    spacing: 6

    Repeater {
        model: 10

        delegate: Rectangle {
            id: wsRow
            required property int index
            readonly property int wsId: index + 1
            readonly property var classes: Hypr.classesByWorkspace(wsId)
            readonly property bool isActive: Hypr.activeId === wsId

            width: parent.width
            height: 40
            radius: 10
            color: isActive ? Theme.withAlpha(Theme.activeAccent, 0.14) : Theme.surfaceFaint
            border.width: isActive ? 1.2 : 0
            border.color: Theme.activeAccent

            Behavior on color { ColorAnimation { duration: Theme.durMed } }
            Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: String(wsRow.wsId)
                    color: wsRow.isActive ? Theme.activeAccent : Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                    width: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: Theme.durMed } }
                }

                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: wsRow.classes

                        delegate: Item {
                            id: appIcon
                            required property string modelData

                            readonly property bool hasIcon: Quickshell.hasThemeIcon(modelData)

                            width: 20
                            height: 20

                            IconImage {
                                anchors.fill: parent
                                visible: appIcon.hasIcon
                                source: appIcon.hasIcon ? Quickshell.iconPath(appIcon.modelData) : ""
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !appIcon.hasIcon
                                radius: 4
                                color: Theme.surfaceHover

                                Text {
                                    anchors.centerIn: parent
                                    text: (appIcon.modelData || "?").charAt(0).toUpperCase()
                                    color: Theme.textMuted
                                    font.pixelSize: 10
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
                    font.pixelSize: 10
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
