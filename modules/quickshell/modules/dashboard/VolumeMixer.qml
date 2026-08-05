import QtQuick
import QtQuick.Effects
import qs.services

// Mezclador de volumen por dispositivo — salidas y entradas, cada una con
// su propio slider + mute, como en la referencia (Volume.qml expone
// playbackNodes/captureNodes vía Quickshell.Services.Pipewire).
//
// Hito 004 follow-up 11: pase estético (pedido explícito: "más grande, más
// glow/color, se siente más responsive") — antes cada fila era plana
// (barra de 6px sin glow, ícono a tamaño fijo pequeño, sin feedback al
// arrastrar) y se sentía utilitaria. Ahora las filas tienen más aire
// (spacing/height subidos), la barra de progreso tiene su propio glow por
// MultiEffect (misma técnica que Dashboard.qml/Bar.qml, coloreada según
// mute) y el thumb crece al arrastrar para que el drag se sienta con peso.
Column {
    id: root
    spacing: 16

    component DeviceRow: Row {
        id: row
        required property var node
        width: parent ? parent.width : 260
        height: 38
        spacing: 10

        readonly property bool isMuted: row.node && row.node.audio ? row.node.audio.muted : false
        readonly property real vol: row.node && row.node.audio ? row.node.audio.volume : 0
        readonly property color barColor: row.isMuted ? Theme.textMuted : Theme.activeAccent

        Text {
            text: row.isMuted ? "󰝟" : "󰕾"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: row.isMuted ? Theme.danger : Theme.activeAccent
            width: 22
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Theme.durMed } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: Volume.toggleMute(row.node)
            }
        }

        Column {
            width: row.width - 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                text: Volume.nodeLabel(row.node)
                elide: Text.ElideRight
                width: parent.width
                color: Theme.textPrimary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }

            Rectangle {
                id: track
                width: parent.width
                height: 9
                radius: 4.5
                color: Theme.surfaceFaint
                border.width: 1
                border.color: Theme.withAlpha(row.barColor, 0.25)

                Behavior on border.color { ColorAnimation { duration: Theme.durMed } }

                Rectangle {
                    id: fill
                    height: parent.height
                    radius: 4.5
                    width: parent.width * Math.min(1, row.vol)
                    color: row.barColor

                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
                    Behavior on color { ColorAnimation { duration: Theme.durMed } }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: row.barColor
                        shadowBlur: 0.6
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => Volume.setVolume(row.node, mouse.x / width)
                    onPositionChanged: mouse => { if (pressed) Volume.setVolume(row.node, Math.max(0, Math.min(1, mouse.x / width))); }
                }

                // Thumb: crece al arrastrar/hoverear para que el drag se
                // sienta con peso — antes no había ningún feedback visual
                // aparte del propio ancho de la barra cambiando.
                Rectangle {
                    width: dragArea.pressed ? 12 : 8
                    height: width
                    radius: width / 2
                    color: Theme.textPrimary
                    x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.vol > 0
                    opacity: dragArea.containsMouse || dragArea.pressed ? 1 : 0.8

                    Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOutBack } }
                }
            }
        }
    }

    Text {
        text: "SALIDA"
        color: Theme.activeAccent
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.bold: true

        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
    }

    Repeater {
        model: Volume.playbackNodes
        delegate: DeviceRow {
            required property var modelData
            node: modelData
            width: root.width
        }
    }

    Text {
        text: "ENTRADA"
        color: Theme.activeAccent
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.bold: true
        topPadding: 6

        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
    }

    Repeater {
        model: Volume.captureNodes
        delegate: DeviceRow {
            required property var modelData
            node: modelData
            width: root.width
        }
    }
}
