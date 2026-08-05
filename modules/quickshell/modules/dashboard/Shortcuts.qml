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
            // Hito 004 follow-up 3: el borde recoge el acento matugen-derivado
            // al pasar el mouse en vez de quedarse en gris fijo — la misma
            // lógica de "aplicar el acento más ampliamente" que los
            // separadores del dashboard, acá como micro-interacción.
            border.color: hover.containsMouse ? Theme.activeAccent : Theme.surfaceBorder

            scale: hover.containsMouse ? 1.08 : 1
            transformOrigin: Item.Center

            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durMed } }
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }

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
                    // Hito 004 follow-up 18: thunar -> dolphin.
                    opener.command = ["dolphin", "/home/jerimy/" + chip.modelData.path];
                    opener.running = true;
                }
            }
        }
    }

    Process { id: opener }
}
