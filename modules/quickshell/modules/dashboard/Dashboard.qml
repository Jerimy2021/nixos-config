import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.dashboard

// Dropdown del dashboard (Hito 004 / Item 3): perfil, toggles rápidos,
// accesos a carpetas, calendario y mezclador de volumen. Se abre desde el
// reloj/capsula de la barra (ver Bar.qml -> UiState.toggleDashboard()).
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
            top: 44
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
            width: 336
            height: 536
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            radius: 22
            color: Theme.surfaceElevated
            border.width: 1.4
            border.color: Theme.withAlpha(Theme.activeAccent, 0.4)

            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.9
            transformOrigin: Item.TopRight

            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutBack } }
            Behavior on border.color { ColorAnimation { duration: Theme.durSlow } }

            MouseArea {
                // absorbe clicks para que no cierren el panel al tocar dentro
                anchors.fill: parent
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 18
                contentHeight: content.implicitHeight
                clip: true

                Column {
                    id: content
                    width: parent.width
                    spacing: 20

                    ProfileHeader {
                        width: parent.width
                    }

                    QuickToggles {}

                    Rectangle { width: parent.width; height: 1; color: Theme.surfaceBorder }

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

                    Rectangle { width: parent.width; height: 1; color: Theme.surfaceBorder }

                    Calendar { width: parent.width }

                    Rectangle { width: parent.width; height: 1; color: Theme.surfaceBorder }

                    VolumeMixer { width: parent.width }
                }
            }
        }
    }
}
