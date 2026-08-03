import QtQuick
import qs.services
import qs.modules.bar

// Pestaña "Performance" del dashboard (Hito 004 follow-up 8): 3 gauges
// circulares reusando CircularGauge.qml (antes solo detrás del icono de
// batería en la barra) contra SystemStats.qml. Bloques explícitos, no
// Repeater sobre un modelo — mismo criterio que SystemCapsules.qml para un
// puñado fijo de widgets distintos entre sí (unidades, escalas y umbrales
// de color propios cada uno).
Column {
    id: root
    spacing: 16

    function ratioColor(ratio) {
        if (ratio >= 0.85) return Theme.danger;
        if (ratio >= 0.6) return Theme.warn;
        return Theme.ok;
    }

    Row {
        width: parent.width
        spacing: 0

        // --- CPU ---
        Column {
            width: parent.width / 3
            spacing: 8

            Item {
                width: 76
                height: 76
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: Math.min(1, SystemStats.cpuTempC / 100)

                CircularGauge {
                    anchors.fill: parent
                    thickness: 5
                    value: parent.ratio
                    progressColor: root.ratioColor(parent.ratio)
                }

                Text {
                    anchors.centerIn: parent
                    text: Math.round(SystemStats.cpuTempC) + "°"
                    color: Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CPU"
                color: Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
        }

        // --- GPU ---
        Column {
            width: parent.width / 3
            spacing: 8

            Item {
                width: 76
                height: 76
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: SystemStats.gpuAvailable ? Math.min(1, SystemStats.gpuTempC / 100) : 0

                CircularGauge {
                    anchors.fill: parent
                    thickness: 5
                    value: parent.ratio
                    trackColor: Theme.surfaceBorder
                    progressColor: SystemStats.gpuAvailable ? root.ratioColor(parent.ratio) : Theme.textMuted
                }

                Text {
                    anchors.centerIn: parent
                    // GPU discreta en PRIME render-offload puro: sin nada
                    // renderizando ahí ahora mismo, nvidia-smi no puede
                    // hablarle al driver (confirmado en vivo, ver
                    // scripts.nix system-stats) — "N/A" es el estado
                    // normal, no un error a esconder ni a forzar.
                    text: SystemStats.gpuAvailable ? (Math.round(SystemStats.gpuTempC) + "°") : "N/A"
                    color: SystemStats.gpuAvailable ? Theme.textPrimary : Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: SystemStats.gpuAvailable ? 15 : 11
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GPU"
                color: Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
        }

        // --- RAM ---
        Column {
            width: parent.width / 3
            spacing: 8

            Item {
                width: 76
                height: 76
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: Math.min(1, SystemStats.memUsedPercent / 100)

                CircularGauge {
                    anchors.fill: parent
                    thickness: 5
                    value: parent.ratio
                    progressColor: root.ratioColor(parent.ratio)
                }

                Text {
                    anchors.centerIn: parent
                    text: Math.round(SystemStats.memUsedPercent) + "%"
                    color: Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RAM"
                color: Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: SystemStats.memUsedGiB.toFixed(1) + " GiB / " + SystemStats.memTotalGiB.toFixed(1) + " GiB"
        color: Theme.textMuted
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
    }
}
