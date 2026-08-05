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
// Hito 004 follow-up 14: rediseño a "pills" compactos — el follow-up 12
// (título completo por ventana, un renglón vertical por ventana) se
// verificó en vivo esta ronda y NO leía compacto: títulos largos (pestaña
// de browser, comando de terminal) ocupaban ~70px de alto por workspace
// para una sola línea de texto elidida a la mitad. Ahora cada ventana es un
// "pill" chico (ícono + nombre corto de la CLASE, no el título) en un Flow
// que empaqueta varias por línea cuando entran — el caso común (1-3 apps
// por workspace) vuelve a caber en una sola línea, igual de alto que la
// fila "vacío". El título completo no se pierde: aparece en un tooltip
// propio al hoverear el pill (mismo criterio que DndToggle.qml — sin
// QtQuick.Controls.Popup, un Rectangle propio con z alto).
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
            // z alto para que el tooltip de cualquier pill (ver abajo) no
            // quede tapado por el fondo de la fila siguiente del Column.
            // Alimentado por cada pill vía HoverHandler (ver dentro del
            // Repeater más abajo).
            property bool tooltipHover: false
            z: tooltipHover ? 10 : 0

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

                    // Flow en vez de Column: varios pills entran en la
                    // misma línea cuando el ancho alcanza, solo baja de
                    // línea cuando hace falta — esto es lo que realmente
                    // ahorra el espacio vertical que el diseño anterior
                    // desperdiciaba (un renglón entero por ventana, sin
                    // importar cuán corto fuera el contenido).
                    Flow {
                        width: parent.width - 30
                        spacing: 6

                        Repeater {
                            model: wsRow.clients

                            delegate: Rectangle {
                                id: pill
                                required property var modelData

                                readonly property bool hasIcon: Quickshell.hasThemeIcon(modelData.class)
                                readonly property string shortName: {
                                    var c = modelData.class || "?";
                                    return c.length > 14 ? c.substring(0, 13) + "…" : c;
                                }

                                height: 24
                                radius: 12
                                color: Theme.surfaceHover
                                width: pillRow.implicitWidth + 16

                                Row {
                                    id: pillRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Item {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter

                                        IconImage {
                                            anchors.fill: parent
                                            visible: pill.hasIcon
                                            source: pill.hasIcon ? Quickshell.iconPath(pill.modelData.class) : ""
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: !pill.hasIcon
                                            radius: 4
                                            color: Theme.withAlpha(Theme.activeAccent, 0.25)

                                            Text {
                                                anchors.centerIn: parent
                                                text: (pill.modelData.class || "?").charAt(0).toUpperCase()
                                                color: Theme.activeAccent
                                                font.pixelSize: 9
                                                font.bold: true
                                                font.family: "JetBrainsMono Nerd Font"
                                            }
                                        }
                                    }

                                    Text {
                                        text: pill.shortName
                                        color: Theme.textPrimary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                HoverHandler {
                                    id: pillHover
                                    onHoveredChanged: wsRow.tooltipHover = hovered
                                }

                                // Tooltip propio (sin QtQuick.Controls.Popup,
                                // mismo criterio que DndToggle.qml): título
                                // completo de la ventana, solo visible en
                                // hover. elide como red de seguridad si el
                                // título es absurdamente largo, no como
                                // solución primaria — la mayoría entra sin
                                // elidir en 260px.
                                Rectangle {
                                    visible: pillHover.hovered
                                    anchors.bottom: pill.top
                                    anchors.bottomMargin: 6
                                    anchors.horizontalCenter: pill.horizontalCenter
                                    width: Math.min(260, tooltipText.implicitWidth + 20)
                                    height: tooltipText.implicitHeight + 12
                                    radius: 8
                                    color: Theme.surfaceElevated
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.activeAccent, 0.4)
                                    z: 20

                                    Text {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        text: pill.modelData.title
                                        color: Theme.textPrimary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                    }
                                }
                            }
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
