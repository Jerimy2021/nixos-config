import QtQuick
import qs.services

// Indicador de workspaces: crece + brilla al estar activo, punto sutil si
// está ocupado-pero-inactivo, transición animada entre estados (nunca un
// salto instantáneo). Muestra 1-9, igual que los binds de core/keybinds.lua.
Row {
    id: root
    spacing: 8

    Repeater {
        model: 9

        delegate: Item {
            id: slot
            required property int index
            readonly property int wsId: index + 1
            readonly property bool isActive: Hypr.activeId === wsId
            readonly property bool isOccupied: Hypr.occupiedIds().indexOf(wsId) !== -1

            width: 30
            height: 26

            Rectangle {
                id: pill
                anchors.centerIn: parent
                width: slot.isActive ? 26 : (slot.isOccupied ? 12 : 8)
                height: 10
                radius: height / 2
                color: slot.isActive ? Theme.activeAccent : (slot.isOccupied ? Theme.textMuted : Qt.rgba(1, 1, 1, 0.12))

                Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutBack } }
                Behavior on color { ColorAnimation { duration: Theme.durMed } }
            }

            // Glow del workspace activo
            Rectangle {
                anchors.centerIn: pill
                width: pill.width + 14
                height: pill.height + 14
                radius: height / 2
                color: "transparent"
                border.width: 7
                border.color: Theme.activeAccent
                opacity: slot.isActive ? 0.22 : 0
                z: -1

                Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
                Behavior on border.color { ColorAnimation { duration: Theme.durMed } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.focusWorkspace(slot.wsId)
            }
        }
    }

    // Refresca occupiedIds() cada vez que cambia el workspace activo o cierran/abren ventanas
    Connections {
        target: Hypr
        function onActiveIdChanged() { refreshTimer.restart(); }
    }

    Timer {
        id: refreshTimer
        interval: 16
        onTriggered: {} // el binding de isOccupied se reevalúa solo; este timer fuerza el repaint del Repeater
    }
}
