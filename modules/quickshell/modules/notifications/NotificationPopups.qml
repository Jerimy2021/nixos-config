import QtQuick
import Quickshell
import qs.services
import qs.modules.notifications

// Pila de toasts flotantes — una tarjeta por notificación activa
// (NotifServer.popups, auto-descartada a los 6s o al hacer click en la X).
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData

        anchors {
            top: true
            right: true
        }
        margins {
            top: 44
            right: 10
        }
        implicitWidth: 320
        implicitHeight: Math.max(1, col.implicitHeight)
        color: "transparent"
        exclusiveZone: 0
        // Oculto mientras el centro de notificaciones está abierto: ambos
        // paneles anclan al mismo top-right, y si ya estás viendo el
        // historial no hace falta un toast duplicado encima.
        visible: NotifServer.popups.length > 0 && !UiState.notifCenterOpen

        Column {
            id: col
            width: parent.width
            spacing: 8

            Repeater {
                model: NotifServer.popups

                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    width: col.width
                    onDismiss: NotifServer.dismissPopup(modelData)
                }
            }
        }
    }
}
