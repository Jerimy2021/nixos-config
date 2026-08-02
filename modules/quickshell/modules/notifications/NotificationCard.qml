import QtQuick
import qs.services

// Tarjeta de notificación individual — usada tanto por los popups
// flotantes como por el historial del centro de notificaciones. Borde
// izquierdo coloreado por urgencia (magenta/cyan/verde, ver NotifServer).
//
// Hito 004 follow-up 6 (ver NIXOS_SHELL_VIDEO_ANALYSIS.md §7.2): gestos
// adaptados de caelestia-dots/shell (GPLv3,
// https://github.com/caelestia-dots/shell,
// modules/notifications/Notification.qml) — arrastre vertical para
// expandir/colapsar el cuerpo completo, swipe horizontal para descartar, y
// el timer de auto-dismiss (NotifServer.dismissTimers) se pausa mientras el
// mouse está encima. NO se porta el modelo de apilado (ListView) de esa
// misma fuente — acá seguimos mostrando una sola tarjeta a la vez (ver
// NotificationPopups.qml), reemplazo por crossfade en vez de stack.
Rectangle {
    id: root

    required property var notification
    property bool dismissable: true
    property bool expanded: false
    signal dismiss

    readonly property color urgencyColor: NotifServer.urgencyColor(notification)

    implicitHeight: col.implicitHeight + 24
    radius: 16
    color: Theme.surfaceElevated
    border.width: 1
    border.color: Theme.surfaceBorder

    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
    Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutCubic } }

    // La misma instancia de tarjeta se reutiliza para notificaciones
    // distintas (ver NotificationPopups.qml, dos slots que se turnan para el
    // crossfade) — sin esto, una tarjeta expandida por la notificación
    // anterior se vería expandida de entrada para la siguiente.
    onNotificationChanged: root.expanded = false

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        radius: 2
        color: root.urgencyColor
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 6
        height: parent.height + 6
        radius: parent.radius + 2
        color: "transparent"
        border.width: 6
        border.color: root.urgencyColor
        opacity: 0.10
        z: -1
    }

    // Zona de gestos — declarada ANTES del botón de cierre para que el
    // MouseArea propio de la X (más abajo en el archivo, por lo tanto
    // pintado encima) siga siendo clickeable en su esquina; esta zona cubre
    // el resto de la tarjeta.
    MouseArea {
        id: gestureArea
        anchors.fill: parent
        hoverEnabled: true
        drag.target: root
        drag.axis: Drag.XAxis
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

        property int startY: 0

        onEntered: NotifServer.pauseDismiss(root.notification)
        onExited: if (!pressed) NotifServer.resumeDismiss(root.notification)

        onPressed: mouse => {
            startY = mouse.y;
            NotifServer.pauseDismiss(root.notification);
        }
        onPositionChanged: mouse => {
            if (pressed) {
                var diffY = mouse.y - startY;
                if (Math.abs(diffY) > 24)
                    root.expanded = diffY > 0;
            }
        }
        onReleased: {
            if (Math.abs(root.x) > root.width * 0.35)
                root.dismiss();
            else
                root.x = 0;
            if (!containsMouse)
                NotifServer.resumeDismiss(root.notification);
        }
        onCanceled: {
            root.x = 0;
            NotifServer.resumeDismiss(root.notification);
        }
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 3

        Row {
            width: parent.width
            Text {
                text: (root.notification.appName || "Sistema").toUpperCase()
                color: root.urgencyColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.bold: true
            }
        }

        Text {
            width: parent.width
            text: root.notification.summary || ""
            color: Theme.textPrimary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.bold: true
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: root.notification.body || ""
            color: Theme.textMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            elide: root.expanded ? Text.ElideNone : Text.ElideRight
            maximumLineCount: root.expanded ? 0 : 3
        }

        // Pista de que se puede arrastrar para ver más — mismo primitivo
        // (MaterialIcon-equivalente con rotación) que usa caelestia para su
        // chevron de expandir, adaptado a nuestros glifos Nerd Font.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: (root.notification.body || "").length > 0
            text: "󰅃"
            rotation: root.expanded ? 180 : 0
            color: Theme.textMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10

            Behavior on rotation { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
        }
    }

    Text {
        visible: root.dismissable
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        text: "󰅖"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: Theme.textMuted

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismiss()
        }
    }
}
