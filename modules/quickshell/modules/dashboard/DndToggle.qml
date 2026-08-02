import QtQuick
import qs.services

// Toggle de "No Molestar" con selector de duración (Hito 004 follow-up 3):
// un click estando apagado despliega un acordeón horizontal con las
// duraciones soportadas (30min/1h/2h/hasta reiniciar); clickear una la
// activa. Estando encendido, un click simple lo apaga de inmediato — el
// submenu de duración solo aparece al ENCENDER, igual que el patrón de
// referencia. Mismo idioma de expansión animada (Behavior on implicitWidth)
// que Capsule.qml, sin depender de QtQuick.Controls.Popup (no usado en
// ningún otro lado de este árbol, y requeriría configurar un estilo nuevo).
Rectangle {
    id: root

    property bool expanded: false
    readonly property bool active: NotifServer.dndEnabled

    height: 56
    radius: 16
    implicitWidth: expanded ? optionsRow.implicitWidth + 24 : 56
    color: active ? Theme.withAlpha(Theme.neonMagenta, 0.18) : Theme.surfaceFaint
    border.width: active ? 1.4 : 1
    border.color: active ? Theme.neonMagenta : Theme.surfaceBorder

    Behavior on implicitWidth { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
    Behavior on color { ColorAnimation { duration: Theme.durMed } }
    Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

    Text {
        anchors.centerIn: parent
        visible: !root.expanded
        text: root.active ? "󰂛" : "󰂚"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 20
        color: root.active ? Theme.neonMagenta : Theme.textMuted

        Behavior on color { ColorAnimation { duration: Theme.durMed } }
    }

    MouseArea {
        anchors.fill: parent
        visible: !root.expanded
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.active) {
                NotifServer.disableDnd();
            } else {
                root.expanded = true;
            }
        }
    }

    Row {
        id: optionsRow
        anchors.centerIn: parent
        spacing: 6
        visible: root.expanded
        opacity: root.expanded ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        component DurationChip: Rectangle {
            id: chip
            property string label: ""
            signal picked

            width: label.length > 2 ? 40 : 32
            height: 34
            radius: 12
            color: chipHover.containsMouse ? Theme.surfaceHover : Theme.surfaceFaint
            border.width: 1
            border.color: Theme.surfaceBorder
            scale: chipHover.containsMouse ? 1.08 : 1

            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }
            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            Text {
                anchors.centerIn: parent
                text: chip.label
                color: Theme.textPrimary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

            MouseArea {
                id: chipHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.picked()
            }
        }

        DurationChip { label: "30m"; onPicked: root.pick(30 * 60 * 1000) }
        DurationChip { label: "1h"; onPicked: root.pick(60 * 60 * 1000) }
        DurationChip { label: "2h"; onPicked: root.pick(2 * 60 * 60 * 1000) }
        DurationChip { label: "∞"; onPicked: root.pick(0) }

        Text {
            text: "󰅖"
            color: Theme.textMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = false
            }
        }
    }

    function pick(durationMs) {
        NotifServer.enableDnd(durationMs);
        root.expanded = false;
    }
}
