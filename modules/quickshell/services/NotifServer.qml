pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Reemplazo de swaync (Hito 004 / Item 4). Único servidor de notificaciones
// del sistema — swaync se retira del autostart para no competir por el
// nombre org.freedesktop.Notifications en el bus de sesión.
Singleton {
    id: root

    property list<var> popups: []
    property list<var> history: []
    property bool dndEnabled: false

    // Duración de DND (Hito 004 follow-up 3): durationMs > 0 arma un timer
    // que lo apaga solo; durationMs === 0 significa "hasta reiniciar" (sin
    // timer, persiste hasta togglearlo a mano o hasta que qs se relance).
    function enableDnd(durationMs) {
        dndTimer.stop();
        root.dndEnabled = true;
        if (durationMs > 0) {
            dndTimer.interval = durationMs;
            dndTimer.start();
        }
    }

    function disableDnd() {
        dndTimer.stop();
        root.dndEnabled = false;
    }

    // Compat: alterna DND sin duración (equivalente a "hasta reiniciar").
    // El picker real (DndToggle.qml) llama enableDnd/disableDnd directo.
    function toggleDnd() {
        if (root.dndEnabled) root.disableDnd(); else root.enableDnd(0);
    }

    Timer {
        id: dndTimer
        onTriggered: root.dndEnabled = false
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: function (notification) {
            notification.tracked = true;

            var historyCopy = root.history.slice();
            historyCopy.unshift(notification);
            if (historyCopy.length > 50) historyCopy.length = 50;
            root.history = historyCopy;

            if (root.dndEnabled) return;

            var popupsCopy = root.popups.slice();
            popupsCopy.push(notification);
            root.popups = popupsCopy;

            dismissTimer.createObject(root, { targetNotif: notification });
        }
    }

    function dismissPopup(notification) {
        var filtered = root.popups.filter(function (n) { return n !== notification; });
        root.popups = filtered;
    }

    function clearHistory() {
        root.history = [];
    }

    function urgencyColor(notification) {
        if (!notification) return Theme.neonCyan;
        var u = notification.urgency;
        if (u === NotificationUrgency.Critical) return Theme.neonMagenta;
        if (u === NotificationUrgency.Low) return Theme.neonGreen;
        return Theme.neonCyan;
    }

    Component {
        id: dismissTimer
        Timer {
            property var targetNotif: null
            interval: 6000
            running: true
            onTriggered: {
                root.dismissPopup(targetNotif);
                destroy();
            }
        }
    }
}
