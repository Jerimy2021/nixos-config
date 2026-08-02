import QtQuick
import Quickshell
import qs.services
import qs.modules.notifications

// Popup de notificación — Hito 004 follow-up 6 (ver
// NIXOS_SHELL_VIDEO_ANALYSIS.md §7.2): antes esto apilaba una tarjeta por
// notificación activa (Column + Repeater sobre NotifServer.popups
// completo). Decisión explícita: una sola tarjeta visible a la vez — si
// llega una notificación nueva mientras hay una visible, la reemplaza con
// crossfade (la vieja se desvanece mientras la nueva aparece), sin cola ni
// conteo de pendientes. Sin precedente directo en caelestia-dots/shell (que
// apila en un ListView) — diseño propio sobre NotificationCard.qml, que sí
// reusa gestos adaptados de esa fuente (ver ese archivo).
//
// Mecanismo: dos slots (A/B) que se turnan como "frente" cada vez que
// cambia la última notificación de NotifServer.popups — el que pasa a
// frente sube a opacity 1, el que estaba de frente baja a 0. Cada slot
// recuerda su propia notificación (aNotif/bNotif) para no reaccionar al
// contenido del otro mientras está invisible.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property var latest: NotifServer.popups.length > 0 ? NotifServer.popups[NotifServer.popups.length - 1] : null

        property var aNotif: null
        property var bNotif: null
        property bool aFront: false

        function showLatest() {
            if (win.aFront) {
                win.bNotif = win.latest;
                win.aFront = false;
            } else {
                win.aNotif = win.latest;
                win.aFront = true;
            }
        }

        onLatestChanged: if (latest) win.showLatest()

        anchors {
            top: true
            right: true
        }
        margins {
            top: 44
            right: 10
        }
        implicitWidth: 320
        implicitHeight: Math.max(cardA.item ? cardA.item.implicitHeight : 0, cardB.item ? cardB.item.implicitHeight : 0)
        color: "transparent"
        // Oculto mientras el centro de notificaciones está abierto: ambos
        // paneles anclan al mismo top-right, y si ya estás viendo el
        // historial no hace falta un toast duplicado encima.
        visible: (latest !== null) && !UiState.notifCenterOpen
        exclusiveZone: 0

        Loader {
            id: cardA
            active: win.aNotif !== null
            opacity: win.aFront ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }

            sourceComponent: NotificationCard {
                notification: win.aNotif
                width: win.implicitWidth
                onDismiss: NotifServer.dismissPopup(win.aNotif)
            }
        }

        Loader {
            id: cardB
            active: win.bNotif !== null
            opacity: win.aFront ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }

            sourceComponent: NotificationCard {
                notification: win.bNotif
                width: win.implicitWidth
                onDismiss: NotifServer.dismissPopup(win.bNotif)
            }
        }
    }
}
