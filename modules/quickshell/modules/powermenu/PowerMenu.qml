import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Menú de sesión/energía (Hito 004 follow-up 3): reemplaza wlogout-launch
// por completo. Superficie flotante independiente de la barra (que sigue
// horizontal arriba sin tocarse) — un trigger compacto en la esquina
// inferior derecha que se despliega en abanico hacia la izquierda.
//
// Reusa el MISMO patrón de proximidad de Capsule.qml (zona invisible más
// grande que el elemento visual + HoverHandler + distancia normalizada al
// centro) en vez de reinventar la lógica — acá el resultado no solo prende
// un glow, controla cuánto se despliega el menú. Un click en el trigger
// también fija el estado abierto (UiState.powerMenuOpen) para poder
// operarlo sin necesidad de "acercarse" — importante también porque este
// entorno de pruebas no tiene forma de sintetizar movimiento de mouse real,
// así que el pin por click es la única vía verificable en vivo aquí.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 20
            right: 16
        }
        implicitWidth: 380
        implicitHeight: 64
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Zona de proximidad: todo el ancho de la ventana, distancia medida
        // al centro del trigger (que vive en el borde derecho). Mismo
        // cálculo que proximityZone en Capsule.qml, aplicado acá para
        // decidir cuánto desplegar en vez de solo un glow.
        Item {
            id: proximityZone
            anchors.fill: parent

            HoverHandler {
                id: proximityHover
                target: proximityZone
            }

            readonly property real amount: {
                if (!proximityHover.hovered) return 0;
                var cx = trigger.x + trigger.width / 2;
                var cy = trigger.y + trigger.height / 2;
                var dx = proximityHover.point.position.x - cx;
                var dy = proximityHover.point.position.y - cy;
                var dist = Math.sqrt(dx * dx + dy * dy);
                var maxDist = win.implicitWidth * 0.85;
                return Math.max(0, 1 - dist / maxDist);
            }
        }

        readonly property bool rowHovered: rowHover.hovered
        readonly property real _rawAmount: Math.max(proximityZone.amount, rowHovered ? 1 : 0, UiState.powerMenuOpen ? 1 : 0)
        property real _amount: _rawAmount
        Behavior on _amount { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }

        HoverHandler {
            id: rowHover
            target: flyout
        }

        Row {
            id: flyout
            anchors.right: trigger.left
            anchors.rightMargin: 10
            anchors.verticalCenter: trigger.verticalCenter
            spacing: 8

            component ActionButton: Rectangle {
                id: btn
                property string icon: "?"
                property color accent: Theme.activeAccent
                signal clicked

                width: 48
                height: 48
                radius: 24
                visible: win._amount > 0.02
                opacity: win._amount
                scale: 0.6 + win._amount * 0.4
                color: hoverArea.containsMouse ? Theme.withAlpha(accent, 0.22) : Theme.surfaceElevated
                border.width: 1.2
                border.color: hoverArea.containsMouse ? accent : Theme.withAlpha(accent, 0.4)

                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

                Text {
                    anchors.centerIn: parent
                    text: btn.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: btn.accent
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: win._amount > 0.05
                    cursorShape: Qt.PointingHandCursor
                    onClicked: btn.clicked()
                }
            }

            ActionButton {
                icon: "󰌾"
                accent: Theme.activeAccent
                onClicked: { lockProc.running = true; UiState.powerMenuOpen = false; }
            }
            ActionButton {
                icon: "󰤄"
                accent: Theme.activeAccent
                onClicked: { suspendProc.running = true; UiState.powerMenuOpen = false; }
            }
            ActionButton {
                icon: "󰍃"
                accent: Theme.warn
                onClicked: { logoutProc.running = true; UiState.powerMenuOpen = false; }
            }
            ActionButton {
                icon: "󰜉"
                accent: Theme.danger
                onClicked: { rebootProc.running = true; UiState.powerMenuOpen = false; }
            }
            ActionButton {
                icon: "󰐥"
                accent: Theme.danger
                onClicked: { shutdownProc.running = true; UiState.powerMenuOpen = false; }
            }
        }

        Rectangle {
            id: trigger
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            radius: 24
            color: Theme.surfaceElevated
            border.width: 1.4
            border.color: Theme.withAlpha(Theme.activeAccent, UiState.powerMenuOpen ? 0.9 : 0.45)

            scale: triggerHover.containsMouse ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }
            Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

            Text {
                anchors.centerIn: parent
                text: "󰐥"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: Theme.activeAccent
            }

            MouseArea {
                id: triggerHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: UiState.togglePowerMenu()
            }
        }

        Process { id: lockProc; command: ["hyprlock"] }
        Process { id: suspendProc; command: ["systemctl", "suspend"] }
        Process { id: logoutProc; command: ["hyprctl", "dispatch", "exit"] }
        Process { id: rebootProc; command: ["systemctl", "reboot"] }
        Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    }
}
