import QtQuick
import QtQuick.Effects
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
    //
    // Hito 004 follow-up 11: pase estético (pedido explícito: "más grande,
    // más glow/color, más impacto visual") — gauges 92→108px, thickness
    // 6→7, y cada anillo ahora proyecta su propio glow (MultiEffect shadow
    // coloreado según ratioColor/estado, misma técnica que ya usa
    // Dashboard.qml para las tarjetas) en vez de flotar plano sobre el
    // fondo.
    Row {
        spacing: 40

        // --- CPU ---
        Column {
            width: 116
            spacing: 12

            Item {
                id: cpuGauge
                width: 108
                height: 108
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: Math.min(1, SystemStats.cpuTempC / 100)
                readonly property color ringColor: root.ratioColor(ratio)

                CircularGauge {
                    anchors.fill: parent
                    thickness: 7
                    value: cpuGauge.ratio
                    progressColor: cpuGauge.ringColor

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: cpuGauge.ringColor
                        shadowBlur: 0.7
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Math.round(SystemStats.cpuTempC) + "°"
                    color: Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CPU"
                color: cpuGauge.ringColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true

                Behavior on color { ColorAnimation { duration: Theme.durMed } }
            }
        }

        // --- GPU ---
        Column {
            width: 116
            spacing: 12

            Item {
                id: gpuGauge
                width: 108
                height: 108
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: SystemStats.gpuAvailable ? Math.min(1, SystemStats.gpuTempC / 100) : 0
                readonly property color ringColor: SystemStats.gpuAvailable ? root.ratioColor(ratio) : Theme.textMuted

                CircularGauge {
                    anchors.fill: parent
                    thickness: 7
                    value: gpuGauge.ratio
                    trackColor: Theme.surfaceBorder
                    progressColor: gpuGauge.ringColor

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: SystemStats.gpuAvailable
                        shadowColor: gpuGauge.ringColor
                        shadowBlur: 0.7
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }
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
                    font.pixelSize: SystemStats.gpuAvailable ? 20 : 14
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GPU"
                color: gpuGauge.ringColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true

                Behavior on color { ColorAnimation { duration: Theme.durMed } }
            }
        }

        // --- RAM ---
        Column {
            width: 116
            spacing: 12

            Item {
                id: ramGauge
                width: 108
                height: 108
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property real ratio: Math.min(1, SystemStats.memUsedPercent / 100)
                readonly property color ringColor: root.ratioColor(ratio)

                CircularGauge {
                    anchors.fill: parent
                    thickness: 7
                    value: ramGauge.ratio
                    progressColor: ramGauge.ringColor

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: ramGauge.ringColor
                        shadowBlur: 0.7
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Math.round(SystemStats.memUsedPercent) + "%"
                    color: Theme.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RAM"
                color: ramGauge.ringColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true

                Behavior on color { ColorAnimation { duration: Theme.durMed } }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: SystemStats.memUsedGiB.toFixed(1) + " GiB / " + SystemStats.memTotalGiB.toFixed(1) + " GiB"
        color: Theme.textMuted
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
    }
}
