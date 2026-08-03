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

    // Hito 004 follow-up 9: antes width:parent.width + cada columna a
    // parent.width/3 — con 0 spacing, los 3 gauges tocaban los bordes de su
    // tercio sin ningún respiro entre sí. Ahora cada columna tiene un ancho
    // fijo propio (bottom-up, no depende del ancho del panel) y el Row
    // reporta su implicitWidth real (3*columnas + spacing) — ese ancho es
    // justamente lo que ahora ensancha el panel para esta pestaña (ver
    // Dashboard.qml card.activeContentWidth case 3). Números de espaciado
    // inspirados en los tokens reales de caelestia-dots/shell
    // (plugin/src/Caelestia/Config/tokens.hpp: perfUsageShapeSize=100,
    // spacing.extraLarge=28) — no importados como dependencia, solo usados
    // como referencia de proporción para que se sienta igual de "airoso".
    Row {
        spacing: 36

        // --- CPU ---
        Column {
            width: 104
            spacing: 10

            Item {
                width: 92
                height: 92
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: Math.min(1, SystemStats.cpuTempC / 100)

                CircularGauge {
                    anchors.fill: parent
                    thickness: 6
                    value: parent.ratio
                    progressColor: root.ratioColor(parent.ratio)
                }

                Text {
                    anchors.centerIn: parent
                    text: Math.round(SystemStats.cpuTempC) + "°"
                    color: Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CPU"
                color: Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }
        }

        // --- GPU ---
        Column {
            width: 104
            spacing: 10

            Item {
                width: 92
                height: 92
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: SystemStats.gpuAvailable ? Math.min(1, SystemStats.gpuTempC / 100) : 0

                CircularGauge {
                    anchors.fill: parent
                    thickness: 6
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
                    font.pixelSize: SystemStats.gpuAvailable ? 17 : 12
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GPU"
                color: Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }
        }

        // --- RAM ---
        Column {
            width: 104
            spacing: 10

            Item {
                width: 92
                height: 92
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: Math.min(1, SystemStats.memUsedPercent / 100)

                CircularGauge {
                    anchors.fill: parent
                    thickness: 6
                    value: parent.ratio
                    progressColor: root.ratioColor(parent.ratio)
                }

                Text {
                    anchors.centerIn: parent
                    text: Math.round(SystemStats.memUsedPercent) + "%"
                    color: Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RAM"
                color: Theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
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
