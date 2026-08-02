import QtQuick
import Quickshell.Io
import qs.services

// Selector manual de wallpaper para el workspace actual (Hito 004 follow-up
// 3). Mismo lenguaje visual que Shortcuts.qml (glass cards, hover scale).
// Al clickear, delega en WorkspaceSync.setWallpaperForCurrent() en vez de
// llamar workspace-wallpaper directo — así la elección queda mapeada al
// workspace igual que el ciclo automático (persiste mientras dure el
// proceso qs) y sigue disparando el cacheo de paleta matugen.
Flow {
    id: root
    spacing: 8

    property var files: []

    Process {
        id: lister
        command: ["bash", "-c", "find \"$HOME/Pictures/Wallpapers\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.trim().length > 0 ? text.trim().split("\n") : []
        }
    }

    Component.onCompleted: lister.running = true

    Repeater {
        model: root.files

        delegate: Rectangle {
            id: card
            required property string modelData
            readonly property bool isActive: modelData === WorkspaceSync.wallpaperFor(Hypr.activeId)

            width: 64
            height: 64
            radius: 12
            color: Theme.surfaceFaint
            border.width: isActive ? 1.6 : 1
            border.color: isActive ? Theme.activeAccent : Theme.surfaceBorder
            clip: true

            scale: hoverArea.containsMouse ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }
            Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: "file://" + card.modelData
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 128
                sourceSize.height: 128
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: WorkspaceSync.setWallpaperForCurrent(card.modelData)
            }
        }
    }
}
