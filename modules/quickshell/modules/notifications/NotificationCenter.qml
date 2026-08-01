import QtQuick
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
            top: 44
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
            width: 316
            height: 436
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            radius: 22
            color: Theme.surfaceElevated
            border.width: 1.4
            border.color: Theme.withAlpha(Theme.neonMagenta, 0.35)

            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.9
            transformOrigin: Item.TopRight

            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutBack } }

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
