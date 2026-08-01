import QtQuick
import qs.services

// Mezclador de volumen por dispositivo — salidas y entradas, cada una con
// su propio slider + mute, como en la referencia (Volume.qml expone
// playbackNodes/captureNodes vía Quickshell.Services.Pipewire).
Column {
    id: root
    spacing: 10

    component DeviceRow: Row {
        id: row
        required property var node
        width: parent ? parent.width : 260
        height: 30
        spacing: 8

        readonly property bool isMuted: row.node && row.node.audio ? row.node.audio.muted : false
        readonly property real vol: row.node && row.node.audio ? row.node.audio.volume : 0

        Text {
            text: row.isMuted ? "󰝟" : "󰕾"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: row.isMuted ? Theme.danger : Theme.activeAccent
            width: 18
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Volume.toggleMute(row.node)
            }
        }

        Column {
            width: row.width - 34
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                text: Volume.nodeLabel(row.node)
                elide: Text.ElideRight
                width: parent.width
                color: Theme.textPrimary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.surfaceFaint

                Rectangle {
                    height: parent.height
                    radius: 3
                    width: parent.width * Math.min(1, row.vol)
                    color: row.isMuted ? Theme.textMuted : Theme.activeAccent

                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
                    Behavior on color { ColorAnimation { duration: Theme.durMed } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => Volume.setVolume(row.node, mouse.x / width)
                    onPositionChanged: mouse => { if (pressed) Volume.setVolume(row.node, Math.max(0, Math.min(1, mouse.x / width))); }
                }
            }
        }
    }

    Text {
        text: "SALIDA"
        color: Theme.textMuted
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        font.bold: true
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
        color: Theme.textMuted
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        font.bold: true
        topPadding: 4
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
