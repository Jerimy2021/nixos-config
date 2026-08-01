pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// No existe un módulo Quickshell.Services.NetworkManager — se sondea nmcli
// por Process, igual que hace el resto del ecosistema quickshell (ver Nmcli.qml
// de caelestia-dots/shell, simplificado aquí a lo que la barra necesita).
Singleton {
    id: root

    property string kind: "none" // none | wifi | ethernet
    property string label: "Sin red"
    property bool connected: false

    function icon() {
        if (kind === "ethernet") return "󰈀";
        if (kind === "wifi") return "󰖩";
        return "󰤭";
    }

    function refresh() {
        proc.running = false;
        proc.running = true;
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    Process {
        id: proc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var found = false;
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":");
                    var type = parts[0];
                    var state = parts[1];
                    var conn = parts.slice(2).join(":");
                    if (state === "connected" && (type === "wifi" || type === "ethernet")) {
                        root.kind = type;
                        root.label = conn || type;
                        root.connected = true;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    root.kind = "none";
                    root.label = "Sin red";
                    root.connected = false;
                }
            }
        }
    }
}
