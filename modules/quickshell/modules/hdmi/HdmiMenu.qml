import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Popup del control de salida HDMI (Hito 004 follow-up 17). Mismo patrón
// que PowerMenu.qml/NotificationCenter.qml (dropdown top-right, sin
// hold-to-confirm acá — a diferencia del menú de energía, ninguna de estas
// 4 acciones es destructiva ni difícil de revertir con otro click).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool shown: UiState.hdmiMenuOpen

        anchors {
            top: true
            right: true
        }
        margins {
            top: 0
            right: 10
        }
        implicitWidth: 300
        // 4 botones de 40px + spacing + encabezado de 2 líneas + márgenes
        // del card — 220 se quedaba corto y recortaba el 4° botón contra
        // el borde real de la superficie Wayland (confirmado en vivo,
        // captura mostraba "Solo laptop" directamente ausente, no elidido
        // ni recortado a la mitad — la ventana entera terminaba ahí).
        implicitHeight: 290
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
            width: 280
            height: win.shown ? contentCol.implicitHeight + 32 : 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            radius: 22
            clip: true
            color: Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)
            border.width: 1.2
            border.color: Theme.withAlpha(Theme.activeAccent, 0.35)

            opacity: win.shown ? 1 : 0

            Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }

            MouseArea { anchors.fill: parent }

            Column {
                id: contentCol
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 12

                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        text: "SALIDA HDMI"
                        color: Theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Text {
                        text: Hdmi.connected ? ("Conectado: " + Hdmi.name) : "Sin cable detectado"
                        color: Hdmi.connected ? Theme.activeAccent : Theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true

                        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
                    }
                }

                component ModeButton: Rectangle {
                    id: btn
                    property string icon: "?"
                    property string label: ""
                    signal clicked

                    width: parent ? parent.width : 240
                    height: 40
                    radius: 12
                    color: hoverArea.containsMouse ? Theme.surfaceHover : Theme.surfaceFaint
                    border.width: 1
                    border.color: Theme.surfaceBorder
                    enabled: Hdmi.connected
                    opacity: Hdmi.connected ? 1 : 0.4

                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            text: btn.icon
                            color: Theme.activeAccent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: btn.label
                            color: Theme.textPrimary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.clicked()
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8

                    ModeButton {
                        icon: "󰍺"
                        label: "Extender"
                        onClicked: Hdmi.setExtend()
                    }
                    ModeButton {
                        icon: "󰃏"
                        label: "Espejo"
                        onClicked: Hdmi.setMirror()
                    }
                    ModeButton {
                        icon: "󰹑"
                        label: "Solo TV"
                        onClicked: Hdmi.setHdmiOnly()
                    }
                    ModeButton {
                        icon: "󰌢"
                        label: "Solo laptop"
                        onClicked: Hdmi.setLaptopOnly()
                    }
                }
            }
        }
    }
}
