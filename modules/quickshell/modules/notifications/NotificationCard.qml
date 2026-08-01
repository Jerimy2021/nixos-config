import QtQuick
import qs.services

// Tarjeta de notificación individual — usada tanto por los popups
// flotantes como por el historial del centro de notificaciones. Borde
// izquierdo coloreado por urgencia (magenta/cyan/verde, ver NotifServer).
Rectangle {
    id: root

    required property var notification
    property bool dismissable: true
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
            elide: Text.ElideRight
            maximumLineCount: 3
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
