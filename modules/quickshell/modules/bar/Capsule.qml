import QtQuick
import qs.services

// Cápsula genérica: icono + valor, usada por todos los módulos del sistema
// en la barra (red, bluetooth, batería, reloj). Un solo archivo = un widget,
// para que agregar módulos nuevos después sea trivial (ver brief Hito 004).
Item {
    id: root

    property string icon: "?"
    property string value: ""
    property color accent: Theme.textPrimary
    property bool active: false
    signal clicked

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 26

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        color: mouseArea.containsMouse ? Theme.surfaceHover : Theme.surfaceFaint
        border.width: root.active ? 1.4 : 1
        border.color: root.active ? root.accent : Theme.surfaceBorder

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durMed } }
    }

    // Halo suave detrás de la cápsula cuando está "activa" (glow sin efectos GPU extra)
    Rectangle {
        anchors.centerIn: parent
        width: bg.width + 10
        height: bg.height + 10
        radius: height / 2
        color: "transparent"
        border.width: 6
        border.color: root.accent
        opacity: root.active ? 0.14 : 0
        z: -1

        Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: root.active ? root.accent : Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Theme.durMed } }
        }

        Text {
            text: root.value
            visible: root.value.length > 0
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Theme.textMuted
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on implicitWidth { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
}
