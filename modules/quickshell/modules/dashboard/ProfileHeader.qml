import QtQuick
import Quickshell.Io
import qs.services

// Bloque de perfil: usuario@host + uptime. Encabezado del dashboard.
Item {
    id: root
    implicitHeight: 64

    property string uptime: "—"

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Rectangle {
            width: 46
            height: 46
            radius: 23
            color: Theme.surfaceHover
            border.width: 2
            border.color: Theme.activeAccent

            Text {
                anchors.centerIn: parent
                text: "󰀄"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                color: Theme.activeAccent
            }

            Behavior on border.color { ColorAnimation { duration: Theme.durSlow } }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: "jerimy@laptop"
                color: Theme.textPrimary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                font.bold: true
            }

            Text {
                text: "󰅐 " + root.uptime
                color: Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: root.uptime = text.trim().replace(/^up /, "")
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeProc.running = true
    }
}
