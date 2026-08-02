import QtQuick
import qs.services

// Barra de pestañas genérica del dashboard (Hito 004 follow-up 5): el
// indicador de pestaña activa desliza entre posiciones (Behavior on x), no
// salta — el ítem de animación que quedó pendiente en el pase anterior por
// no existir todavía ningún sistema de tabs (ver §10.3 de la doc). Un solo
// archivo genérico, reusable si se agregan más pestañas después.
Item {
    id: root

    property var tabs: []
    property int currentIndex: 0
    signal tabClicked(int index)

    implicitHeight: 30
    readonly property real tabWidth: root.tabs.length > 0
        ? (width - (root.tabs.length - 1) * tabRow.spacing) / root.tabs.length
        : 0

    Row {
        id: tabRow
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: root.tabs

            delegate: Item {
                id: tabItem
                required property int index
                required property string modelData

                width: root.tabWidth
                height: tabRow.height

                Text {
                    anchors.centerIn: parent
                    text: tabItem.modelData
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: root.currentIndex === tabItem.index
                    color: root.currentIndex === tabItem.index ? Theme.activeAccent : Theme.textMuted

                    Behavior on color { ColorAnimation { duration: Theme.durMed } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tabClicked(tabItem.index)
                }
            }
        }
    }

    Rectangle {
        id: indicator
        width: root.tabWidth
        height: 2
        radius: 1
        color: Theme.activeAccent
        anchors.bottom: parent.bottom
        x: root.currentIndex * (root.tabWidth + tabRow.spacing)

        Behavior on x { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
    }
}
