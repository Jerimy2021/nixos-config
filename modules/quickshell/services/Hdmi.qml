pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hito 004 follow-up 17: control de salida HDMI (laptop→TV). Sondea
// `hdmi-control status` (ver hosts/laptop/scripts.nix) — ese script lee
// /sys/class/drm/card*-HDMI-A-*/status directo, no hyprctl, porque
// hyprctl monitors NO lista conectores sin señal (confirmado en vivo).
// Mismo patrón Process+Timer que Network.qml.
Singleton {
    id: root

    property bool connected: false
    property string name: ""

    function icon() {
        return connected ? "󰍹" : "󰹑";
    }

    function refresh() {
        proc.running = false;
        proc.running = true;
    }

    function setExtend() { action("extend"); }
    function setMirror() { action("mirror"); }
    function setHdmiOnly() { action("hdmi-only"); }
    function setLaptopOnly() { action("laptop-only"); }

    function action(mode) {
        actionProc.command = ["hdmi-control", mode];
        actionProc.running = true;
        // El monitor recién enchufado/movido tarda un instante en
        // reflejarse — un refresh casi inmediato después de la acción
        // alcanza para que el ícono/estado no quede desactualizado.
        refreshDelay.restart();
    }

    Timer {
        id: refreshDelay
        interval: 800
        onTriggered: root.refresh()
    }

    Process { id: actionProc }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    Process {
        id: proc
        command: ["hdmi-control", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    root.connected = !!data.connected;
                    root.name = data.name || "";
                } catch (e) {
                    // Mantiene el último estado conocido en vez de resetear
                    // a "no conectado" por un parseo fallido puntual —
                    // mismo criterio que SystemStats.qml.
                }
            }
        }
    }
}
