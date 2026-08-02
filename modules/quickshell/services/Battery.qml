pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device ? device.isLaptopBattery : false
    // Bug Hito 004 follow-up: UPowerDevice.percentage en Quickshell 0.3.0 es
    // una fracción 0.0-1.0 (confirmado en vivo: 62% real -> percentage=0.62),
    // no 0-100 como decía el comentario anterior. Math.round(0.62) = 1, de
    // ahí el "1%" fantasma. Hay que escalar a 0-100 antes de redondear.
    readonly property real percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging) : false
    readonly property bool fullyCharged: device ? (device.state === UPowerDeviceState.FullyCharged) : false

    function icon() {
        if (!present) return "󰚥";
        if (fullyCharged) return "󰁹";
        if (charging) return "󰂄";
        if (percent <= 15) return "󰁻";
        if (percent <= 40) return "󰁽";
        if (percent <= 70) return "󰂀";
        return "󰁹";
    }
}
