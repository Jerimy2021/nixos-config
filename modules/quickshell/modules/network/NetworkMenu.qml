import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import qs.services

// Selector real de redes WiFi (Hito 004 follow-up 19). Reemplaza
// `nmApplet.startDetached()` (spawneaba un ícono de bandeja externo,
// nm-applet --indicator — ni siquiera una lista, solo un tray icon aparte)
// por una lista QML propia dentro del mismo lenguaje visual del resto del
// shell.
//
// Se investigó primero si esto era posible en absoluto: rondas anteriores
// de este hito (ver Network.qml) habían asumido "no existe un módulo
// Quickshell.Services.NetworkManager" y resuelto todo vía `nmcli` por
// Process. Se revisó de nuevo antes de repetir ese patrón acá — la versión
// de quickshell instalada (0.3.0) SÍ trae `Quickshell.Networking`
// (`quickshell-network.qmltypes`, confirmado inspeccionándolo
// directamente), con soporte real de NetworkManager vía D-Bus: `Networking`
// (singleton), `NetworkDevice`/`WifiDevice`, `Network`/`WifiNetwork` con
// `connect()`/`connectWithPsk(psk)`/`forget()`. Esto SÍ es la opción
// "D-Bus, preferida" del pedido — no hizo falta el fallback de
// nmtui/nm-connection-editor en ventana flotante.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool shown: UiState.networkMenuOpen

        anchors {
            top: true
            right: true
        }
        margins {
            top: 0
            right: 10
        }
        implicitWidth: 320
        implicitHeight: 420
        color: "transparent"
        visible: shown || hideDelay.running
        exclusiveZone: 0
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // El escaneo activo de redes consume energía/radio — solo se
        // habilita mientras el popup está realmente abierto, se apaga al
        // cerrar (mismo criterio que cualquier polling caro en este
        // proyecto, ver Timer de SystemStats.qml).
        readonly property var wifiDevice: {
            var list = Networking.devices ? Networking.devices.values : [];
            for (var i = 0; i < list.length; i++) {
                if (list[i].type === DeviceType.Wifi) return list[i];
            }
            return null;
        }

        // Un solo onShownChanged — QML no permite dos handlers para la
        // misma señal en el mismo objeto ("Property value set multiple
        // times", encontrado en vivo al separarlos en dos bloques).
        onShownChanged: {
            if (!shown) hideDelay.restart();
            if (win.wifiDevice) win.wifiDevice.scannerEnabled = win.shown;
        }

        Timer {
            id: hideDelay
            interval: Theme.durMed + 30
        }

        MouseArea {
            anchors.fill: parent
            enabled: win.shown
            onClicked: UiState.closeAll()
        }

        Rectangle {
            id: card
            width: 300
            height: win.shown ? Math.min(420, contentCol.implicitHeight + 32) : 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            radius: 22
            clip: true
            color: Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)
            border.width: 1.2
            border.color: Theme.withAlpha(Theme.blue, 0.35)

            opacity: win.shown ? 1 : 0

            Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }

            MouseArea { anchors.fill: parent }

            Column {
                id: contentCol
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                spacing: 10

                // Item, no Row — un header "space-between" (label a la
                // izquierda, toggle a la derecha) necesita anclar el
                // segundo hijo a la derecha, y Row no lo permite en sus
                // hijos directos ("Cannot specify ... anchors for items
                // inside Row", encontrado en vivo).
                Item {
                    width: parent.width
                    height: 24

                    Text {
                        text: "REDES WIFI"
                        color: Theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Networking.wifiEnabled ? "ON" : "OFF"
                        color: Networking.wifiEnabled ? Theme.ok : Theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }
                }

                Text {
                    visible: !win.wifiDevice
                    text: "Sin adaptador WiFi detectado"
                    color: Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.italic: true
                }

                Text {
                    visible: win.wifiDevice && win.wifiDevice.networks.values.length === 0
                    text: "Escaneando…"
                    color: Theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.italic: true
                }

                Flickable {
                    width: parent.width
                    height: Math.min(300, list.implicitHeight)
                    contentHeight: list.implicitHeight
                    clip: true

                    Column {
                        id: list
                        width: parent.width
                        spacing: 6

                        Repeater {
                            // Ordenadas por señal descendente — la red más
                            // fuerte (probablemente la relevante) arriba,
                            // no en el orden crudo que devuelve NetworkManager.
                            model: {
                                if (!win.wifiDevice) return [];
                                var nets = win.wifiDevice.networks.values.slice();
                                nets.sort(function (a, b) { return b.signalStrength - a.signalStrength; });
                                return nets;
                            }

                            delegate: Rectangle {
                                id: row
                                required property var modelData

                                readonly property bool isOpen: modelData.security === WifiSecurityType.Open
                                readonly property bool needsPassword: !modelData.known && !isOpen
                                property bool expanded: false

                                width: list.width
                                height: expanded ? 84 : 40
                                radius: 12
                                color: modelData.connected ? Theme.withAlpha(Theme.activeAccent, 0.16) : (hoverArea.containsMouse ? Theme.surfaceHover : Theme.surfaceFaint)
                                border.width: modelData.connected ? 1.2 : 0
                                border.color: Theme.activeAccent

                                Behavior on height { NumberAnimation { duration: Theme.durFast } }
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.top: parent.top
                                    height: 40
                                    spacing: 10

                                    Text {
                                        // Barras según intensidad — mismo umbral
                                        // que usa Network.icon() para el ícono de
                                        // la cápsula, acá con más granularidad.
                                        text: modelData.signalStrength >= 75 ? "󰤨" : modelData.signalStrength >= 50 ? "󰤥" : modelData.signalStrength >= 25 ? "󰤢" : "󰤟"
                                        color: modelData.connected ? Theme.activeAccent : Theme.textMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        width: parent.width - 70
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        color: Theme.textPrimary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.bold: modelData.connected
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        visible: !row.isOpen
                                        text: "󰌾"
                                        color: Theme.textMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        visible: modelData.connected
                                        text: "✓"
                                        color: Theme.activeAccent
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Campo de contraseña — solo aparece para
                                // redes desconocidas con seguridad (no
                                // Open, no ya guardadas por NetworkManager).
                                Row {
                                    visible: row.expanded
                                    anchors.top: parent.top
                                    anchors.topMargin: 44
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    spacing: 6

                                    Rectangle {
                                        width: parent.width - 60
                                        height: 30
                                        radius: 8
                                        color: Theme.surface
                                        border.width: 1
                                        border.color: Theme.withAlpha(Theme.activeAccent, 0.4)

                                        TextInput {
                                            id: pskInput
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            color: Theme.textPrimary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            echoMode: TextInput.Password
                                            focus: row.expanded
                                            onAccepted: {
                                                row.modelData.connectWithPsk(text);
                                                row.expanded = false;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 50
                                        height: 30
                                        radius: 8
                                        color: Theme.withAlpha(Theme.activeAccent, 0.25)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "OK"
                                            color: Theme.activeAccent
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                row.modelData.connectWithPsk(pskInput.text);
                                                row.expanded = false;
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: hoverArea
                                    anchors.top: parent.top
                                    width: parent.width
                                    height: 40
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (row.modelData.connected) {
                                            // ya conectada: click no hace nada
                                            // destructivo — desconectar por
                                            // accidente es peor que no hacer
                                            // nada.
                                            return;
                                        }
                                        if (row.needsPassword) {
                                            row.expanded = !row.expanded;
                                        } else {
                                            row.modelData.connect();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
