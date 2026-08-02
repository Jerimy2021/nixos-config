import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Menú de energía (Hito 004 follow-up 6, ver NIXOS_SHELL_VIDEO_ANALYSIS.md
// §7.1): el trigger ahora vive en Bar.qml como una Capsule más, junto a los
// lanzadores de Discord/Spotify — este archivo reemplaza por completo la
// versión anterior (dock flotante con expansión por proximidad en la
// esquina inferior derecha). Una vez que el trigger vive en la barra, la
// proximidad no tenía ningún propósito: se elimina toda esa lógica, no
// coexiste con esta versión. El panel es un dropdown top-right más, mismo
// patrón que Dashboard.qml / NotificationCenter.qml (PanelWindow anclado
// top+right, card con opacity+scale animados, cierre al click afuera vía
// UiState.closeAll()) — más consistente que inventar un cuarto patrón de
// despliegue.
//
// Confirmación antes de ejecutar (mantener presionado ~600ms, arco de
// progreso radial en cada ActionButton): requisito propio sin precedente en
// el video de referencia ni en el proyecto fuente real (caelestia-dots/shell
// — modules/session/Content.qml ejecuta al instante en click/Enter, sin
// ningún paso de confirmación) — diseño nuevo, no adaptado de ningún lado.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool shown: UiState.powerMenuOpen

        anchors {
            top: true
            right: true
        }
        margins {
            top: 44
            right: 10
        }
        implicitWidth: 360
        implicitHeight: 140
        color: "transparent"
        visible: shown || hideDelay.running
        exclusiveZone: 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        onShownChanged: if (!shown) hideDelay.restart()

        Timer {
            id: hideDelay
            interval: Theme.durMed + 30
        }

        // Cierra al hacer click fuera de la tarjeta
        MouseArea {
            anchors.fill: parent
            enabled: win.shown
            onClicked: UiState.closeAll()
        }

        Rectangle {
            id: card
            width: 336
            height: 118
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            radius: 22
            color: Theme.surfaceElevated
            border.width: 1.4
            border.color: Theme.withAlpha(Theme.danger, 0.35)

            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.9
            transformOrigin: Item.TopRight

            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutBack } }
            Behavior on border.color { ColorAnimation { duration: Theme.durSlow } }

            // Absorbe clicks para que no cierren el panel al tocar dentro
            MouseArea { anchors.fill: parent }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ENERGÍA · mantené presionado"
                    color: Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                }

                Row {
                    id: actions
                    spacing: 12

                    component ActionButton: Item {
                        id: btn
                        property string icon: "?"
                        property color accent: Theme.activeAccent
                        // 0..1 mientras se mantiene presionado — confirma la
                        // acción al llegar a 1 (ver holdAnim). Soltar antes
                        // lo cancela (releaseAnim) sin ejecutar nada.
                        property real holdProgress: 0
                        signal confirmed

                        width: 52
                        height: 52

                        Rectangle {
                            id: circle
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            radius: 22
                            color: hoverArea.containsMouse ? Theme.withAlpha(btn.accent, 0.22) : Theme.surfaceFaint
                            border.width: 1.2
                            border.color: Theme.withAlpha(btn.accent, 0.4)

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            Text {
                                anchors.centerIn: parent
                                text: btn.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: btn.accent
                            }
                        }

                        // Arco de progreso circular — mismo primitivo
                        // (Shape/ShapePath/PathAngleArc) que usa
                        // caelestia-dots/shell para su indicador de progreso
                        // de notificaciones (modules/notifications/
                        // Notification.qml), reutilizado acá solo como
                        // técnica de dibujo, no como código adaptado — la
                        // lógica de hold-to-confirm es diseño propio sin
                        // referencia real (ver comentario de archivo).
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            visible: btn.holdProgress > 0.001

                            ShapePath {
                                strokeWidth: 3
                                strokeColor: btn.accent
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: btn.width / 2
                                    centerY: btn.height / 2
                                    radiusX: btn.width / 2 - 2
                                    radiusY: btn.height / 2 - 2
                                    startAngle: -90
                                    sweepAngle: btn.holdProgress * 360
                                }
                            }
                        }

                        NumberAnimation {
                            id: holdAnim
                            target: btn
                            property: "holdProgress"
                            from: 0
                            to: 1
                            duration: 600
                            onFinished: {
                                if (btn.holdProgress >= 1) {
                                    btn.confirmed();
                                    btn.holdProgress = 0;
                                }
                            }
                        }

                        NumberAnimation {
                            id: releaseAnim
                            target: btn
                            property: "holdProgress"
                            to: 0
                            duration: Theme.durFast
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPressed: {
                                releaseAnim.stop();
                                btn.holdProgress = 0;
                                holdAnim.restart();
                            }
                            onReleased: {
                                if (btn.holdProgress < 1) {
                                    holdAnim.stop();
                                    releaseAnim.restart();
                                }
                            }
                            onCanceled: {
                                holdAnim.stop();
                                releaseAnim.restart();
                            }
                        }
                    }

                    ActionButton {
                        icon: "󰌾"
                        accent: Theme.activeAccent
                        onConfirmed: { lockProc.running = true; UiState.closeAll(); }
                    }
                    ActionButton {
                        icon: "󰤄"
                        accent: Theme.activeAccent
                        onConfirmed: { suspendProc.running = true; UiState.closeAll(); }
                    }
                    ActionButton {
                        icon: "󰍃"
                        accent: Theme.warn
                        onConfirmed: { logoutProc.running = true; UiState.closeAll(); }
                    }
                    ActionButton {
                        icon: "󰜉"
                        accent: Theme.danger
                        onConfirmed: { rebootProc.running = true; UiState.closeAll(); }
                    }
                    ActionButton {
                        icon: "󰐥"
                        accent: Theme.danger
                        onConfirmed: { shutdownProc.running = true; UiState.closeAll(); }
                    }
                }
            }
        }

        Process { id: lockProc; command: ["hyprlock"] }
        Process { id: suspendProc; command: ["systemctl", "suspend"] }
        Process { id: logoutProc; command: ["hyprctl", "dispatch", "exit"] }
        Process { id: rebootProc; command: ["systemctl", "reboot"] }
        Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    }
}
