import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.notifications

// Centro de notificaciones (historial) — mismo lenguaje visual que el
// dashboard (glass + glow), abierto desde la campana de la barra.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool shown: UiState.notifCenterOpen

        anchors {
            top: true
            right: true
        }
        margins {
            // Hito 004 follow-up 7 (ver Dashboard.qml, mismo fix y misma
            // aclaración sobre cómo Hyprland mide este margin — 0 queda
            // pegado exacto al borde real de la barra, no 38).
            top: 0
            right: 10
        }
        implicitWidth: 340
        implicitHeight: 460
        color: "transparent"
        visible: shown || hideDelay.running
        exclusiveZone: 0
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onShownChanged: if (!shown) hideDelay.restart()

        Timer {
            id: hideDelay
            interval: Theme.durMed + 30
        }

        MouseArea {
            anchors.fill: parent
            enabled: win.shown
            onClicked: UiState.closeAll()
        }

        Rectangle {
            id: card
            readonly property int fullHeight: 436

            width: 316
            height: win.shown ? fullHeight : 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: 4
            clip: true

            radius: 22
            // Mismo razonamiento que Dashboard.qml: esquinas superiores
            // cuadradas + sin gap + sin borde propio en el tope, para que la
            // silueta continúe la de la barra en vez de leerse como tarjeta
            // aparte.
            topLeftRadius: 0
            topRightRadius: 0
            // Mismo tinte que Bar.qml/Dashboard.qml en vez de
            // Theme.surfaceElevated, para que coincida en la costura. La
            // identidad magenta de notificaciones se conserva en las
            // NotificationCard (borde de urgencia) y en la cápsula de la
            // barra — no hace falta repetirla como borde de todo el panel.
            color: Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)

            opacity: win.shown ? 1 : 0

            Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.5
                shadowVerticalOffset: 3
                shadowHorizontalOffset: 0
            }

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Row {
                    width: parent.width
                    height: 24

                    Text {
                        text: "NOTIFICACIONES"
                        color: Theme.textPrimary
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: NotifServer.history.length > 0
                        text: "Limpiar"
                        color: Theme.neonMagenta
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifServer.clearHistory()
                        }
                    }
                }

                Text {
                    visible: NotifServer.history.length === 0
                    text: "Sin notificaciones"
                    color: Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 40
                }

                Flickable {
                    width: parent.width
                    height: parent.height - 40
                    contentHeight: list.implicitHeight
                    clip: true
                    visible: NotifServer.history.length > 0

                    Column {
                        id: list
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: NotifServer.history

                            delegate: NotificationCard {
                                required property var modelData
                                notification: modelData
                                dismissable: false
                                width: list.width
                            }
                        }
                    }
                }
            }
        }
    }
}
