import QtQuick
import Quickshell.Io
import qs.services

// Accesos directos a carpetas — abren Thunar (el explorador ya declarado
// en home.nix) en la ruta elegida.
Flow {
    id: root
    spacing: 8

    readonly property var folders: [
        { label: "Inicio", icon: "󰋜", path: "" },
        { label: "Descargas", icon: "󰉍", path: "Downloads" },
        { label: "Documentos", icon: "󰈙", path: "Documents" },
        { label: "Imágenes", icon: "󰋩", path: "Pictures" },
        { label: "Proyectos", icon: "󰲌", path: "system" }
    ]

    Repeater {
        model: root.folders

        delegate: Rectangle {
            id: chip
            required property var modelData

            width: label.implicitWidth + 26
            height: 32
            radius: 16
            color: hover.containsMouse ? Theme.surfaceHover : Theme.surfaceFaint
            border.width: 1
            border.color: Theme.surfaceBorder

            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: chip.modelData.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: Theme.activeAccent
                }

                Text {
                    id: label
                    text: chip.modelData.label
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    opener.command = ["thunar", "/home/jerimy/" + chip.modelData.path];
                    opener.running = true;
                }
            }
        }
    }

    Process { id: opener }
}
