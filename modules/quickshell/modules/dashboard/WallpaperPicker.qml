import QtQuick
import Quickshell.Io
import qs.services

// Selector manual de wallpaper para el workspace actual (Hito 004 follow-up
// 3). Mismo lenguaje visual que Shortcuts.qml (glass cards, hover scale).
// Al clickear, delega en WorkspaceSync.setWallpaperForCurrent() en vez de
// llamar workspace-wallpaper directo — así la elección queda mapeada al
// workspace igual que el ciclo automático (persiste mientras dure el
// proceso qs) y sigue disparando el cacheo de paleta matugen.
//
// Hito 004 follow-up 13: antes vivía apretado en la pestaña "Wallpapers"
// del dashboard (336px de ancho, miniaturas de 64px). Esa pestaña se quitó
// — este componente ahora es el contenido de WallpaperPickerPopup.qml, un
// popup propio con mucho más ancho disponible, así que las miniaturas
// crecieron a 88px con más espacio entre sí para sentirse como un picker
// real y no como un apéndice comprimido.
Flow {
    id: root
    spacing: 12

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

            width: 88
            height: 88
            radius: 14
            color: Theme.surfaceFaint
            border.width: isActive ? 2 : 1
            border.color: isActive ? Theme.activeAccent : Theme.surfaceBorder
            clip: true

            scale: hoverArea.containsMouse ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }
            Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

            Image {
                anchors.fill: parent
                anchors.margins: 3
                source: "file://" + card.modelData
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 176
                sourceSize.height: 176
            }

            // Marca de "activo" — la esquina inferior-derecha, además del
            // borde acentuado, para que se note incluso al pasar rápido la
            // mirada por la grilla.
            Rectangle {
                visible: card.isActive
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                width: 18
                height: 18
                radius: 9
                color: Theme.activeAccent

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: Theme.surface
                    font.pixelSize: 11
                    font.bold: true
                }
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
