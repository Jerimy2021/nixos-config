import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Grupo de cápsulas del sistema: red, bluetooth, batería y reloj.
// Cada una es una Capsule reactiva a su servicio correspondiente.
Row {
    id: root
    spacing: 8

    Capsule {
        icon: Network.icon()
        value: Network.connected ? Network.label : ""
        active: Network.connected
        accent: Theme.blue
        onClicked: nmApplet.startDetached()

        Process {
            id: nmApplet
            command: ["nm-applet-ctl", "toggle"]
        }
    }

    Capsule {
        icon: BluetoothStatus.icon()
        value: BluetoothStatus.connectedCount > 0 ? String(BluetoothStatus.connectedCount) : ""
        active: BluetoothStatus.powered
        accent: Theme.lavender
        onClicked: BluetoothStatus.toggle()
    }

    Capsule {
        icon: Battery.icon()
        value: Battery.present ? (Battery.percent + "%") : ""
        active: Battery.charging
        accent: Battery.percent <= 15 && !Battery.charging ? Theme.danger : Theme.pink
    }

    Capsule {
        id: clock
        icon: "󰥔"
        value: Qt.formatDateTime(now.date, "hh:mm")
        accent: Theme.activeAccent
        active: false
        onClicked: UiState.toggleDashboard()

        SystemClock {
            id: now
            precision: SystemClock.Minutes
        }
    }
}
