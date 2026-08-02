pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

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

    // Bug Hito 004 follow-up: el toggle "no hacía nada" no era un problema de
    // wiring — adapter.enabled = true ya estaba correctamente conectado a
    // setEnabled y funciona (confirmado en vivo: onPoweredChanged disparó
    // true->false->true con toggle() puro). La causa real observada en este
    // equipo: el radio estaba rfkill soft-blocked (`bluetoothctl power on`
    // falla idéntico — "org.bluez.Error.Failed" — completamente fuera de
    // QuickShell). Con soft-block activo, BlueZ rechaza Powered=true en
    // silencio: el click "no hacía nada" porque el estado real nunca cambiaba.
    // BluetoothAdapter de Quickshell.Bluetooth NO expone el estado rfkill
    // (esa propiedad "blocked" existe solo en BluetoothDevice, no en el
    // adapter — lo confirmé leyendo el qmltypes y me equivoqué al asumirlo
    // al adapter en un intento anterior). Como no hay señal QML para
    // detectarlo, la solución robusta es desbloquear rfkill como parte de
    // "encender" siempre: un unblock sobre un adaptador ya desbloqueado es
    // no-op, así que no hay costo en el caso común.
    Process {
        id: rfkillUnblock
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: (exitCode, exitStatus) => {
            if (root.adapter) root.adapter.enabled = true;
        }
    }

    function toggle() {
        if (!adapter) return;
        if (adapter.enabled) {
            adapter.enabled = false;
        } else {
            rfkillUnblock.running = true;
        }
    }
}
