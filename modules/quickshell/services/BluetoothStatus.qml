pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property var devices: adapter ? adapter.devices : null

    readonly property int connectedCount: {
        if (!devices || !devices.values) return 0;
        var count = 0;
        var values = devices.values;
        for (var i = 0; i < values.length; i++) {
            if (values[i].connected) count++;
        }
        return count;
    }

    function icon() {
        if (!powered) return "󰂲";
        if (connectedCount > 0) return "󰂱";
        return "󰂯";
    }

    function toggle() {
        if (adapter) adapter.enabled = !adapter.enabled;
    }
}
