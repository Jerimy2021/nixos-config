pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estadísticas de sistema para la pestaña "Performance" del dashboard (Hito
// 004 follow-up 8). Sondeado por Process cada 6s, mismo patrón que
// Network.qml (Timer + Process + StdioCollector, sin módulo Quickshell
// nativo para esto). Toda la lógica frágil (buscar el hwmon de coretemp,
// tolerar que la GPU no responda) vive en el script `system-stats` (ver
// hosts/laptop/scripts.nix) — acá solo se parsea el JSON que devuelve.
Singleton {
    id: root

    property real cpuTempC: 0
    property real gpuTempC: -1 // -1 = no disponible (GPU en PRIME offload sin despertar, ver scripts.nix)
    property bool gpuAvailable: false
    property real memUsedPercent: 0
    property real memUsedGiB: 0
    property real memTotalGiB: 0

    function refresh() {
        proc.running = false;
        proc.running = true;
    }

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    Process {
        id: proc
        command: ["system-stats"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    root.cpuTempC = data.cpuTempC || 0;
                    root.gpuAvailable = data.gpuTempC !== null;
                    root.gpuTempC = root.gpuAvailable ? data.gpuTempC : -1;
                    root.memUsedPercent = data.memUsedPercent || 0;
                    root.memUsedGiB = data.memUsedGiB || 0;
                    root.memTotalGiB = data.memTotalGiB || 0;
                } catch (e) {
                    // deja los últimos valores buenos conocidos en vez de resetear a 0
                }
            }
        }
    }
}
