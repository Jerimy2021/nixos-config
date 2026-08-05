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
// Hito 004 follow-up 15 — cuatro refinamientos sobre la versión anterior:
//
// (a) Centrado torcido a la derecha, reportado en el escritorio real. Se
// midió en vivo (captura + comparación contra el centro real de pantalla,
// no solo revisión de código): en una copia de prueba limpia el card SÍ
// centraba casi exacto (682.5px medido vs 683px = centro real de 1366px).
// No se logró reproducir el corrimiento a la derecha en ese entorno. Sí se
// encontró y corrigió una causa real y plausible: la Column de encabezado
// ("FONDOS DE PANTALLA"/"Activo:") tenía `width: parent.width` apuntando a
// `contentCol`, cuyo propio ancho depende de sus hijos — un binding
// circular real (Column.implicitWidth intenta usar el width ya asignado
// de sus hijos, pero ese width depende de vuelta del resultado). Qt no
// garantiza un orden de resolución para binding loops así — es exactamente
// el tipo de bug que puede comportarse distinto según timing/orden de
// creación, lo que encajaría con "en la copia de prueba fresca no se ve,
// en la instancia real de larga duración sí". Reemplazado por un ancho fijo
// compartido (`pickerWidth`) igual al de WallpaperPicker, sin ciclo
// posible. Pendiente que el usuario reconfirme en su escritorio real.
//
// (b) Ancla al fondo de pantalla en vez del tope (mismo criterio de
// costura sin gap que ya usan Dashboard.qml/NotificationCenter.qml/
// PowerMenu.qml contra la barra, acá aplicado al borde inferior real de
// pantalla — no hay ninguna otra superficie exclusiveZone ahí, así que
// margin 0 sí es el borde físico, a diferencia del margin-top de esos
// otros paneles).
//
// (c) Layout de grilla (Flow) → filmstrip horizontal, ver WallpaperPicker.qml.
//
// (d) Glow de Theme.activeAccent: además del que ya gana cada miniatura
// (ver WallpaperPicker.qml), el card completo pasa de sombra negra plana a
// sombra coloreada con el acento — misma técnica MultiEffect que el resto
// del dashboard (Dashboard.qml follow-up 11), aplicada acá por primera vez
// a este popup.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool shown: UiState.wallpaperPickerOpen

        anchors {
            bottom: true
            left: true
            right: true
        }
        margins {
            // Sin otra exclusiveZone reservada en el borde inferior — 0 acá
            // sí es el borde físico real de la pantalla (a diferencia del
            // margin-top de Dashboard.qml/NotificationCenter.qml, que
            // arranca después de la exclusiveZone de la barra).
            bottom: 0
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

            // Ancho fijo compartido con WallpaperPicker (ver comentario
            // (a) arriba) — antes la Column de encabezado usaba
            // `width: parent.width` (ciclo real contra contentCol), ahora
            // ambos usan esta misma constante, sin binding circular
            // posible.
            readonly property real pickerWidth: 560
            readonly property real targetHeight: Math.max(200, Math.min(480, contentCol.implicitHeight + 40))

            width: pickerWidth + 40
            height: win.shown ? targetHeight : 0
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true

            Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }

            radius: 22
            // Esquinas inferiores cuadradas ahora (antes eran las
            // superiores, cuando el panel colgaba del tope) — el borde que
            // toca al borde real de pantalla es el de abajo.
            bottomLeftRadius: 0
            bottomRightRadius: 0
            color: Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)

            opacity: win.shown ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }

            // (d): sombra coloreada con el acento en vez de negro plano —
            // mismo criterio "glow" que el resto del dashboard.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.withAlpha(Theme.activeAccent, 0.5)
                shadowBlur: 0.6
                shadowVerticalOffset: 0
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
                    width: card.pickerWidth
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
                    width: card.pickerWidth
                }
            }
        }
    }
}
