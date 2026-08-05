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

    // Hito 004 follow-up 17: cápsula HDMI, oculta por completo cuando no
    // hay cable enchufado (Hdmi.connected, sondeado vía sysfs — ver
    // Hdmi.qml) para no ensuciar la barra en la sesión normal (sin TV) que
    // es la inmensa mayoría del tiempo de uso de este laptop.
    Capsule {
        visible: Hdmi.connected
        icon: Hdmi.icon()
        value: ""
        active: UiState.hdmiMenuOpen
        accent: Theme.ok
        onClicked: UiState.toggleHdmiMenu()
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
        // Anillo de carga real detrás del icono — Hito 004 follow-up: prioriza
        // claridad visual del nivel sobre precisión del número exacto.
        gauge: Battery.present ? Battery.percent / 100 : -1
    }

    Capsule {
        id: clock
        icon: "󰥔"
        value: Qt.formatDateTime(now.date, "hh:mm")
        accent: Theme.activeAccent
        active: UiState.dashboardOpen
        onClicked: UiState.toggleDashboard()

        // Hito 004 follow-up 10: el trigger de apertura por hover se movió a
        // TODA la barra (ver HoverHandler en Bar.qml, `surface`) — antes
        // vivía acá y solo abría al pasar exactamente sobre la cápsula del
        // reloj, lo que en vivo resultó ser un blanco chico y poco obvio
        // (nadie lo encontraba sin que se lo mostraran). El click acá sigue
        // funcionando igual (toggle manual), pero ya no hace falta este
        // hover local — dejarlo hubiera sido una segunda fuente de verdad
        // redundante con la de Bar.qml.
        SystemClock {
            id: now
            precision: SystemClock.Minutes
        }
    }
}
