import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.bar

// Cápsula genérica: icono + valor, usada por todos los módulos del sistema
// en la barra (red, bluetooth, batería, reloj). Un solo archivo = un widget,
// para que agregar módulos nuevos después sea trivial (ver brief Hito 004).
Item {
    id: root

    property string icon: "?"
    property string value: ""
    property color accent: Theme.textPrimary
    property bool active: false
    // -1 = sin anillo (comportamiento original); 0..1 = dibuja CircularGauge
    // detrás del icono (hoy solo la batería lo usa, ver SystemCapsules.qml).
    property real gauge: -1
    // Ícono real (Quickshell.iconPath(...)) en vez del glifo de texto — hoy
    // lo usan los lanzadores de apps (AppLaunchers.qml): un logo real de
    // Discord/Spotify, no un glifo genérico de Nerd Font. Vacío = comportamiento
    // original (glifo de texto en `icon`).
    property string iconSource: ""
    signal clicked

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 26

    scale: mouseArea.containsMouse ? 1.08 : 1
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }

    // Zona de "proximidad": más grande que la cápsula real, sin recorte
    // visual (no tiene color propio). El glow de abajo no solo reacciona al
    // hover binario sobre la cápsula sino que se acerca gradualmente según
    // la distancia del cursor al centro — el efecto "se despierta según te
    // acercas" pedido en el follow-up de animación de Hito 004.
    Item {
        id: proximityZone
        anchors.centerIn: parent
        width: parent.width + 60
        height: parent.height + 40

        HoverHandler {
            id: proximityHover
            target: proximityZone
        }

        readonly property real amount: {
            if (!proximityHover.hovered) return 0;
            var dx = proximityHover.point.position.x - proximityZone.width / 2;
            var dy = proximityHover.point.position.y - proximityZone.height / 2;
            var dist = Math.sqrt(dx * dx + dy * dy);
            var maxDist = Math.max(proximityZone.width, proximityZone.height) / 2;
            return Math.max(0, 1 - dist / maxDist);
        }
    }

    property real _proximity: proximityZone.amount
    Behavior on _proximity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }

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

    // Halo suave detrás de la cápsula: máximo si está "activa", tenue y
    // proporcional a la proximidad del cursor en cualquier otro caso (nunca
    // en 0 salvo con el mouse lejos, nunca instantáneo).
    Rectangle {
        anchors.centerIn: parent
        width: bg.width + 10
        height: bg.height + 10
        radius: height / 2
        color: "transparent"
        border.width: 6
        border.color: root.accent
        opacity: root.active ? 0.14 : root._proximity * 0.10
        z: -1

        Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Item {
            id: iconSlot
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            CircularGauge {
                anchors.fill: parent
                visible: root.gauge >= 0
                value: root.gauge
                progressColor: root.accent
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                visible: root.iconSource.length > 0
                source: root.iconSource
            }

            Text {
                anchors.centerIn: parent
                visible: root.iconSource.length === 0
                text: root.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: root.active ? root.accent : Theme.textPrimary

                Behavior on color { ColorAnimation { duration: Theme.durMed } }
            }
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
