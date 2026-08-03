import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.dashboard

// Dropdown del dashboard (Hito 004 / Item 3): perfil, toggles rápidos,
// accesos a carpetas, calendario y mezclador de volumen. Se abre desde el
// reloj/capsula de la barra (ver Bar.qml -> UiState.toggleDashboard()).
//
// Hito 004 follow-up 5: antes todo esto era una sola columna vertical
// dentro de un Flickable — el picker de wallpapers agregado en el follow-up
// anterior la sobrecargaba, empujando el calendario hacia abajo. Ahora hay
// pestañas (Dashboard/Wallpapers/Media, ver TabBar.qml) y cada una tiene su
// propio Flickable independiente, así el scroll de una no afecta a las
// otras. ProfileHeader queda fuera de las pestañas (identidad/saludo, no es
// contenido específico de ninguna).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool shown: UiState.dashboardOpen

        anchors {
            top: true
            right: true
        }
        margins {
            // Hito 004 follow-up 7: antes 44, dejaba un hueco visible entre
            // el borde real de la barra y esta tarjeta — se leía como "una
            // ventana aparte", no como "la barra se extiende". OJO: este
            // margin NO se mide desde el borde de pantalla — Hyprland ya
            // arranca el área utilizable justo después de la exclusiveZone
            // de Bar.qml (38), así que margin 0 = pegado exacto al borde
            // real de la barra (confirmado en vivo con hyprctl layers,
            // comparando la geometría del panel contra la de la barra).
            top: 0
            right: 10
        }
        implicitWidth: 360
        implicitHeight: 560
        color: "transparent"
        visible: shown || hideDelay.running
        exclusiveZone: 0
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onShownChanged: if (!shown) hideDelay.restart()

        Timer {
            id: hideDelay
            interval: Theme.durMed + 30
        }

        // Cierra al hacer click fuera del panel
        MouseArea {
            anchors.fill: parent
            enabled: win.shown
            onClicked: UiState.closeAll()
        }

        Rectangle {
            id: card
            readonly property int fullHeight: 536

            width: 336
            height: win.shown ? fullHeight : 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: 4
            clip: true

            radius: 22
            // Esquinas superiores cuadradas a propósito (Qt 6.7+,
            // confirmado 6.11.1 en uso — ver NIXOS_SHELL_VIDEO_ANALYSIS.md
            // §7.6/§7.7): con el hueco cerrado (margin top:38) y sin borde
            // propio en el tope, la silueta de esta tarjeta continúa
            // directo la silueta rectangular de la barra en vez de leerse
            // como una tarjeta redondeada flotando aparte.
            topLeftRadius: 0
            topRightRadius: 0
            // Mismo tinte que Bar.qml (Theme.tintSurface) en vez de
            // Theme.surfaceElevated — para que el color coincida exacto en
            // la costura donde esta tarjeta toca el fondo de la barra.
            color: Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)

            opacity: win.shown ? 1 : 0

            Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }

            // Sin borde propio (antes 1.4px acento) ni sombra separada: un
            // borde en las 4 caras habría dibujado una línea justo en la
            // costura con la barra. Elevación solo por sombra (misma técnica
            // que Bar.qml, MultiEffect estándar de QtQuick.Effects) —
            // shadowVerticalOffset positivo hace que se note en los bordes
            // izquierdo/derecho/inferior y sea prácticamente invisible en el
            // borde superior, que es justo la costura que debe leerse como
            // una sola forma continua con la barra.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.5
                shadowVerticalOffset: 3
                shadowHorizontalOffset: 0
            }

            MouseArea {
                // absorbe clicks para que no cierren el panel al tocar dentro
                anchors.fill: parent
            }

            Item {
                anchors.fill: parent
                anchors.margins: 18

                ProfileHeader {
                    id: profileHeader
                    anchors.top: parent.top
                    width: parent.width
                }

                TabBar {
                    id: tabBar
                    anchors.top: profileHeader.bottom
                    anchors.topMargin: 14
                    width: parent.width
                    tabs: ["Dashboard", "Wallpapers", "Media"]
                    currentIndex: UiState.dashboardTab
                    onTabClicked: index => UiState.setDashboardTab(index)
                }

                Rectangle {
                    id: tabDivider
                    anchors.top: tabBar.bottom
                    anchors.topMargin: 8
                    width: parent.width
                    height: 1
                    color: Theme.withAlpha(Theme.activeAccent, 0.18)

                    Behavior on color { ColorAnimation { duration: Theme.durSlow } }
                }

                Item {
                    id: tabContent
                    anchors.top: tabDivider.bottom
                    anchors.topMargin: 14
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true

                    // Carrusel horizontal (Hito 004 follow-up 6, ver
                    // NIXOS_SHELL_VIDEO_ANALYSIS.md §7.3) — reemplaza el
                    // salto instantáneo (visible: dashboardTab === N) por un
                    // slide animado. Mecanismo adaptado de
                    // caelestia-dots/shell (GPLv3,
                    // https://github.com/caelestia-dots/shell,
                    // modules/dashboard/Content.qml): un Flickable con las
                    // pestañas puestas en fila y contentX animado hacia la
                    // pestaña activa. No se porta su sistema de Loader con
                    // activación diferida por visibleArea — nuestras 3
                    // pestañas son livianas, activarlas todas de una no es
                    // un problema de performance real hoy. Tampoco se
                    // habilita swipe manual (interactive: false) — fuera de
                    // alcance de esta ronda, solo el click en la tab anima.
                    Flickable {
                        id: carousel
                        anchors.fill: parent
                        interactive: false
                        contentWidth: tabsRow.implicitWidth
                        contentHeight: height
                        contentX: UiState.dashboardTab * width

                        Behavior on contentX {
                            NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic }
                        }

                        Row {
                            id: tabsRow

                            // --- Pestaña "Dashboard": toggles rápidos, accesos, calendario ---
                            Flickable {
                                width: carousel.width
                                height: carousel.height
                                contentHeight: dashboardTabContent.implicitHeight
                                clip: true

                                Column {
                                    id: dashboardTabContent
                                    width: parent.width
                                    spacing: 20

                                    QuickToggles { width: parent.width }

                                    Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.activeAccent, 0.18); Behavior on color { ColorAnimation { duration: Theme.durSlow } } }

                                    Column {
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            text: "ACCESOS"
                                            color: Theme.textMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        Shortcuts { width: parent.width }
                                    }

                                    Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.activeAccent, 0.18); Behavior on color { ColorAnimation { duration: Theme.durSlow } } }

                                    Calendar { width: parent.width }
                                }
                            }

                            // --- Pestaña "Wallpapers": picker de miniaturas (Hito 004 follow-up 3) ---
                            Flickable {
                                width: carousel.width
                                height: carousel.height
                                contentHeight: wallpaperTabContent.implicitHeight
                                clip: true

                                Column {
                                    id: wallpaperTabContent
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        text: "FONDOS"
                                        color: Theme.textMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    WallpaperPicker { width: parent.width }
                                }
                            }

                            // --- Pestaña "Media": mezclador de volumen por dispositivo ---
                            Flickable {
                                width: carousel.width
                                height: carousel.height
                                contentHeight: mediaTabContent.implicitHeight
                                clip: true

                                Column {
                                    id: mediaTabContent
                                    width: parent.width
                                    VolumeMixer { width: parent.width }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
