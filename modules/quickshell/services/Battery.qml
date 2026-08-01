pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device ? device.isLaptopBattery : false
    // UPower reporta percentage en escala 0-100.
    readonly property real percent: device ? Math.round(device.percentage) : 0
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
