import QtQuick
import qs.services

// Calendario mensual simple, con navegación y el día de hoy resaltado.
Column {
    id: root
    spacing: 8

    property date viewDate: new Date()
    readonly property date today: new Date()

    readonly property var monthNames: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    readonly property var dayNames: ["L", "M", "X", "J", "V", "S", "D"]

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
    function mondayIndex(jsDay) { return (jsDay + 6) % 7; } // JS: 0=domingo -> queremos 0=lunes

    Row {
        width: parent.width
        height: 28

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅁"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: Theme.textMuted
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1)
            }
        }

        Text {
            width: parent.width - 60
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: root.monthNames[root.viewDate.getMonth()] + " " + root.viewDate.getFullYear()
            color: Theme.textPrimary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅂"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: Theme.textMuted
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1)
            }
        }
    }

    Grid {
        columns: 7
        rowSpacing: 6
        columnSpacing: 4
        width: parent.width

        Repeater {
            model: root.dayNames
            delegate: Text {
                required property string modelData
                width: (root.width - 24) / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
        }

        Repeater {
            model: root.mondayIndex(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), 1).getDay())
            delegate: Item {
                width: (root.width - 24) / 7
                height: 26
            }
        }

        Repeater {
            model: root.daysInMonth(root.viewDate.getFullYear(), root.viewDate.getMonth())
            delegate: Item {
                required property int index
                readonly property int day: index + 1
                readonly property bool isToday: day === root.today.getDate() && root.viewDate.getMonth() === root.today.getMonth() && root.viewDate.getFullYear() === root.today.getFullYear()

                width: (root.width - 24) / 7
                height: 26

                Rectangle {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: 12
                    color: isToday ? Theme.activeAccent : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.durMed } }
                }

                Text {
                    anchors.centerIn: parent
                    text: day
                    color: isToday ? "#0a0a12" : Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: isToday
                }
            }
        }
    }
}
