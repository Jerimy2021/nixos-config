import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services

// Popup standalone del selector de wallpapers (Hito 004 follow-up 13,
// pedido explícito: "Wallpapers" deja de ser pestaña del dashboard, pasa a
// ser su propio popup disparado por keybind — SUPER+CTRL+W, ver
// keybinds.lua, repuntado desde abrir el dashboard).
//
// Estudio de referencia (~/reference/caelestia-shell, GPLv3,
// https://github.com/caelestia-dots/shell) antes de decidir el mecanismo:
// - modules/launcher/WallpaperList.qml + items/WallpaperItem.qml: picker
//   integrado al launcher (PathView 3D tipo carrusel de portadas, con
//   preview en vivo del wallpaper vía su servicio Wallpapers.qml antes de
//   confirmar). Es el candidato estructuralmente más parecido a lo pedido
//   (keybind → popup propio → browse → seleccionar), PERO su PathView
//   depende de Caelestia.Config (Tokens) y de su propio sistema de
//   preview/Colours que no existe acá — NO se porta el mecanismo, solo la
//   idea de "popup propio disparado por keybind, no anidado".
// - modules/nexus/pages/wallandstyle/WallpaperSelect.qml +
//   WallpaperCategory.qml: página de una app de configuración completa
//   (Nexus), agrupada por categorías de carpeta — confirmado que NO encaja
//   acá: pensada para navegación dentro de una app de settings, no para un
//   popup efímero de keybind.
// - services/Wallpapers.qml: sí hubiera sido reusable como *servicio* de
//   datos (listar wallpapers, current path) si no tuviéramos ya el
//   equivalente — pero WorkspaceSync.qml ya cubre exactamente ese rol acá
//   (wallpaperFor()/setWallpaperForCurrent(), integrado con nuestro propio
//   pipeline workspace-wallpaper + matugen). No se adopta el mecanismo de
//   cambio de wallpaper de caelestia (su comando `caelestia wallpaper`) —
//   solo el patrón de UI (popup con grilla, atribución de cuál está
//   activo), aplicado sobre nuestros scripts existentes.
//
// Estructura de ventana: mismo patrón que Dashboard.qml (centrado bajo la
// barra, costura sin gap) en vez del top-right de PowerMenu/NotificationCenter
// — una grilla de wallpapers se beneficia más del ancho extra que da centrar
// que de quedar pegada a una esquina.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool shown: UiState.wallpaperPickerOpen

        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            // Mismo hallazgo que Dashboard.qml/NotificationCenter.qml: este
            // margin no se mide desde el borde de pantalla, Hyprland ya
            // arranca el área utilizable después de la exclusiveZone de
            // Bar.qml — 0 = pegado exacto al borde real de la barra.
            top: 0
        }
        implicitHeight: 480
        color: "transparent"
        visible: shown || hideDelay.running
        exclusiveZone: 0
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onShownChanged: if (!shown) hideDelay.restart()

        Timer {
            id: hideDelay
            interval: Theme.durMed + 30
        }

        // Cierra al hacer click fuera del panel
        MouseArea {
            anchors.fill: parent
            enabled: win.shown
            onClicked: UiState.closeAll()
        }

        Rectangle {
            id: card

            readonly property real targetWidth: Math.max(320, Math.min(760, contentCol.implicitWidth + 40))
            readonly property real targetHeight: Math.max(200, Math.min(480, contentCol.implicitHeight + 40))

            width: targetWidth
            height: win.shown ? targetHeight : 0
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true

            Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }

            radius: 22
            // Mismo razonamiento que Dashboard.qml/NotificationCenter.qml:
            // esquinas superiores cuadradas + sin borde propio en el tope
            // para que la silueta continúe la de la barra.
            topLeftRadius: 0
            topRightRadius: 0
            color: Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)

            opacity: win.shown ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.5
                shadowVerticalOffset: 3
                shadowHorizontalOffset: 0
            }

            MouseArea {
                // absorbe clicks para que no cierren el panel al tocar dentro
                anchors.fill: parent
            }

            Column {
                id: contentCol
                anchors.centerIn: parent
                spacing: 14

                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        text: "FONDOS DE PANTALLA"
                        color: Theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    // Atribución de cuál está activo (además del check en
                    // la propia miniatura, ver WallpaperPicker.qml) —
                    // nombre de archivo legible, no la ruta completa.
                    Text {
                        readonly property string activePath: WorkspaceSync.wallpaperFor(Hypr.activeId)
                        text: "Activo: " + activePath.substring(activePath.lastIndexOf("/") + 1)
                        color: Theme.activeAccent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true

                        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
                    }
                }

                WallpaperPicker {
                    width: 560
                }
            }
        }
    }
}
