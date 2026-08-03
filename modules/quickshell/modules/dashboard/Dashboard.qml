import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.dashboard

// Dropdown del dashboard (Hito 004 / Item 3): perfil, toggles rápidos,
// accesos a carpetas, calendario y mezclador de volumen. Se abre desde el
// reloj/capsula de la barra (ver Bar.qml -> UiState.toggleDashboard()).
//
// Hito 004 follow-up 5: antes todo esto era una sola columna vertical
// dentro de un Flickable — el picker de wallpapers agregado en el follow-up
// anterior la sobrecargaba, empujando el calendario hacia abajo. Ahora hay
// pestañas (Dashboard/Wallpapers/Media, ver TabBar.qml) y cada una tiene su
// propio Flickable independiente, así el scroll de una no afecta a las
// otras. ProfileHeader queda fuera de las pestañas (identidad/saludo, no es
// contenido específico de ninguna).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool shown: UiState.dashboardOpen

        // Hito 004 follow-up 9 (ver NIXOS_ARCHITECTURE_HITO_004.md, estudio
        // de ~/reference/caelestia-shell modules/dashboard/Wrapper.qml): la
        // ventana ahora ocupa el ancho completo de la pantalla (como
        // Bar.qml) en vez de anclar solo a la derecha — la tarjeta se centra
        // DENTRO de esa ventana (ver anchors.horizontalCenter en `card`),
        // igual que el `anchors.horizontalCenter: parent.horizontalCenter`
        // del Loader de contenido en su Wrapper.qml. No se porta su
        // mecanismo real (una única ventana de pantalla completa con
        // máscaras de click-through por Region — mucho más complejo, pensado
        // para su sistema de deformación de blobs) — acá el efecto visual
        // equivalente (dropdown centrado bajo la barra) se logra con el
        // patrón de anclaje ya usado en Bar.qml, sin inventar un tercer
        // sistema de ventana.
        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            // OJO: este margin NO se mide desde el borde de pantalla —
            // Hyprland ya arranca el área utilizable justo después de la
            // exclusiveZone de Bar.qml (38), así que margin 0 = pegado
            // exacto al borde real de la barra (confirmado en vivo con
            // hyprctl layers, comparando la geometría del panel contra la de
            // la barra).
            top: 0
        }
        implicitHeight: 560
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

            // Hito 004 follow-up 8: antes una constante fija (536, tuneada a
            // ojo para que la pestaña Dashboard entrara sin scroll). Con 5
            // pestañas de altura bien distinta (Performance son 3 gauges
            // cortos, Workspaces puede ser una lista de 10 filas) una sola
            // constante o dejaba hueco vacío de sobra o forzaba scroll
            // innecesario. Ahora se calcula: "chrome" compartido (perfil +
            // tab bar + divisor + márgenes, medido en vivo vía las propias
            // implicitHeight de esos ítems, no hardcodeado) más la altura
            // natural del contenido de LA PESTAÑA ACTIVA — así el Behavior
            // on height que ya existía (antes solo para abrir/cerrar) anima
            // también el cambio al levantarse/bajar entre pestañas de altura
            // distinta, sin necesidad de tocar ese Behavior.
            readonly property real chromeHeight: profileHeader.height + 14 + tabBar.height + 8 + 1 + 14 + 36
            readonly property real activeContentHeight: {
                switch (UiState.dashboardTab) {
                case 0: return dashboardTabContent.implicitHeight;
                case 1: return wallpaperTabContent.implicitHeight;
                case 2: return mediaTabContent.implicitHeight;
                case 3: return perfTabContent.implicitHeight;
                case 4: return wsTabContent.implicitHeight;
                default: return 0;
                }
            }
            readonly property real targetHeight: Math.max(260, Math.min(560, chromeHeight + activeContentHeight))

            // Hito 004 follow-up 9: antes 336 fijo para las 5 pestañas por
            // igual — dejaba Dashboard/Performance apretadas y no dejaba
            // lugar para el layout de tarjetas lado a lado que pide esta
            // ronda (ver dashboardTabContent/perfTabContent más abajo).
            // Mecanismo adaptado de caelestia-dots/shell
            // (modules/dashboard/Content.qml, `nonAnimWidth: view.
            // implicitWidth + margins*2`) — acá el ancho natural viene de LA
            // PESTAÑA ACTIVA, igual que ya hacíamos con la altura. Solo
            // Dashboard (case 0) y Performance (case 3) reportan un ancho
            // realmente bottom-up esta ronda (Row de tarjetas de ancho fijo,
            // ver más abajo) — Wallpapers/Media/Workspaces no se tocan este
            // round y se quedan con el ancho fijo de siempre (336) para no
            // introducir una dependencia circular con su propio
            // width:parent.width interno.
            readonly property real activeContentWidth: {
                switch (UiState.dashboardTab) {
                case 0: return dashboardTabContent.implicitWidth;
                case 3: return perfTabContent.implicitWidth;
                default: return 336;
                }
            }
            readonly property real targetWidth: Math.max(320, Math.min(760, activeContentWidth + 36))

            // A diferencia de height, width no colapsa a un valor mínimo al
            // cerrar — con height:0 nada es visible de todos modos, y
            // encogerla también generaría un segundo achicamiento simultáneo
            // que no aporta nada visualmente (la métafora es "la solapa se
            // pliega hacia arriba", no "se encoge hacia un punto").
            width: targetWidth
            height: win.shown ? targetHeight : 0
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true

            Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }

            radius: 22
            // Esquinas superiores cuadradas a propósito (Qt 6.7+,
            // confirmado 6.11.1 en uso — ver NIXOS_SHELL_VIDEO_ANALYSIS.md
            // §7.6/§7.7): con el hueco cerrado (margin top:38) y sin borde
            // propio en el tope, la silueta de esta tarjeta continúa
            // directo la silueta rectangular de la barra en vez de leerse
            // como una tarjeta redondeada flotando aparte.
            topLeftRadius: 0
            topRightRadius: 0
            // Mismo tinte que Bar.qml (Theme.tintSurface) en vez de
            // Theme.surfaceElevated — para que el color coincida exacto en
            // la costura donde esta tarjeta toca el fondo de la barra.
            color: Theme.tintSurface(Theme.surface, Theme.activeAccent, 0.6)

            opacity: win.shown ? 1 : 0

            Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }

            // Sin borde propio (antes 1.4px acento) ni sombra separada: un
            // borde en las 4 caras habría dibujado una línea justo en la
            // costura con la barra. Elevación solo por sombra (misma técnica
            // que Bar.qml, MultiEffect estándar de QtQuick.Effects) —
            // shadowVerticalOffset positivo hace que se note en los bordes
            // izquierdo/derecho/inferior y sea prácticamente invisible en el
            // borde superior, que es justo la costura que debe leerse como
            // una sola forma continua con la barra.
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

            Item {
                anchors.fill: parent
                anchors.margins: 18

                ProfileHeader {
                    id: profileHeader
                    anchors.top: parent.top
                    width: parent.width
                }

                TabBar {
                    id: tabBar
                    anchors.top: profileHeader.bottom
                    anchors.topMargin: 14
                    width: parent.width
                    tabs: ["Dashboard", "Wallpapers", "Media", "Performance", "Workspaces"]
                    currentIndex: UiState.dashboardTab
                    onTabClicked: index => UiState.setDashboardTab(index)
                }

                Rectangle {
                    id: tabDivider
                    anchors.top: tabBar.bottom
                    anchors.topMargin: 8
                    width: parent.width
                    height: 1
                    color: Theme.withAlpha(Theme.activeAccent, 0.18)

                    Behavior on color { ColorAnimation { duration: Theme.durSlow } }
                }

                Item {
                    id: tabContent
                    anchors.top: tabDivider.bottom
                    anchors.topMargin: 14
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true

                    // Carrusel horizontal (Hito 004 follow-up 6, ver
                    // NIXOS_SHELL_VIDEO_ANALYSIS.md §7.3) — reemplaza el
                    // salto instantáneo (visible: dashboardTab === N) por un
                    // slide animado. Mecanismo adaptado de
                    // caelestia-dots/shell (GPLv3,
                    // https://github.com/caelestia-dots/shell,
                    // modules/dashboard/Content.qml): un Flickable con las
                    // pestañas puestas en fila y contentX animado hacia la
                    // pestaña activa. No se porta su sistema de Loader con
                    // activación diferida por visibleArea — nuestras 3
                    // pestañas son livianas, activarlas todas de una no es
                    // un problema de performance real hoy. Tampoco se
                    // habilita swipe manual (interactive: false) — fuera de
                    // alcance de esta ronda, solo el click en la tab anima.
                    //
                    // Hito 004 follow-up 9: `contentX: index * width` asumía
                    // que las 5 pestañas medían lo mismo — dejó de ser cierto
                    // en cuanto Dashboard/Performance pasaron a tener un
                    // ancho propio distinto del resto (ver `card.
                    // activeContentWidth`). Adaptado del mismo Content.qml
                    // (su Flickable ata `contentX` a `currentItem.x`, la
                    // posición real que el propio Row ya le asignó a esa
                    // pestaña según la suma de anchos/spacing de las
                    // anteriores) — acá cada Flickable de pestaña tiene su
                    // propio ancho natural (`xxxContent.implicitWidth`) en
                    // vez de `carousel.width` forzado, y `contentX` apunta al
                    // `.x` que el Row calculó para la pestaña activa.
                    Flickable {
                        id: carousel
                        anchors.fill: parent
                        interactive: false
                        contentWidth: tabsRow.implicitWidth
                        contentHeight: height
                        contentX: {
                            switch (UiState.dashboardTab) {
                            case 0: return dashboardTabFlick.x;
                            case 1: return wallpaperTabFlick.x;
                            case 2: return mediaTabFlick.x;
                            case 3: return perfTabFlick.x;
                            case 4: return wsTabFlick.x;
                            default: return 0;
                            }
                        }

                        Behavior on contentX {
                            NumberAnimation { duration: Theme.durMed; easing.type: Theme.easeOutCubic }
                        }

                        Row {
                            id: tabsRow

                            // --- Pestaña "Dashboard": tarjetas lado a lado (Hito 004 follow-up 9) ---
                            // Antes: una sola Column vertical apretando
                            // QuickToggles+Shortcuts+Calendar en 336px de
                            // ancho fijo. Reestructurado como Row de 2
                            // tarjetas de ancho fijo generoso (idea tomada de
                            // caelestia-dots/shell modules/dashboard/Dash.qml
                            // — su GridLayout de 6 celdas con anchos por
                            // Layout.preferredWidth — adaptada a nuestro
                            // contenido real, no copiada literal: nosotros no
                            // tenemos weather/user-con-foto, así que son 2
                            // tarjetas, no 6). Cada tarjeta reporta un ancho
                            // fijo propio (no parent.width) para que el Row
                            // tenga un implicitWidth bottom-up real — así
                            // `card.activeContentWidth` (ver arriba) puede
                            // medirlo sin depender circularmente del ancho
                            // del panel.
                            Flickable {
                                id: dashboardTabFlick
                                width: dashboardTabContent.implicitWidth
                                height: carousel.height
                                contentHeight: dashboardTabContent.implicitHeight
                                clip: true

                                Row {
                                    id: dashboardTabContent
                                    spacing: 20

                                    readonly property real cardHeight: Math.max(quickAccessCol.implicitHeight, calendarCol.implicitHeight) + 40

                                    // Tarjeta 1: toggles rápidos + accesos a carpetas
                                    Rectangle {
                                        width: 280
                                        height: dashboardTabContent.cardHeight
                                        radius: 18
                                        color: Theme.surfaceFaint

                                        Column {
                                            id: quickAccessCol
                                            anchors.centerIn: parent
                                            width: parent.width - 40
                                            spacing: 16

                                            QuickToggles { width: parent.width }

                                            Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.activeAccent, 0.18); Behavior on color { ColorAnimation { duration: Theme.durSlow } } }

                                            Column {
                                                width: parent.width
                                                spacing: 8
                                                Text {
                                                    text: "ACCESOS"
                                                    color: Theme.textMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                                Shortcuts { width: parent.width }
                                            }
                                        }
                                    }

                                    // Tarjeta 2: calendario
                                    Rectangle {
                                        width: 300
                                        height: dashboardTabContent.cardHeight
                                        radius: 18
                                        color: Theme.surfaceFaint

                                        Column {
                                            id: calendarCol
                                            anchors.centerIn: parent
                                            width: parent.width - 40

                                            Calendar { width: parent.width }
                                        }
                                    }
                                }
                            }

                            // --- Pestaña "Wallpapers": picker de miniaturas (Hito 004 follow-up 3) ---
                            // Ancho fijo sin tocar esta ronda (ver
                            // card.activeContentWidth) — width:336 explícito
                            // acá en vez de parent.width para no depender
                            // circularmente del ancho del Flickable, que a su
                            // vez ahora depende del ancho de ESTE Column.
                            Flickable {
                                id: wallpaperTabFlick
                                width: wallpaperTabContent.implicitWidth
                                height: carousel.height
                                contentHeight: wallpaperTabContent.implicitHeight
                                clip: true

                                Column {
                                    id: wallpaperTabContent
                                    width: 336
                                    spacing: 8

                                    Text {
                                        text: "FONDOS"
                                        color: Theme.textMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    WallpaperPicker { width: parent.width }
                                }
                            }

                            // --- Pestaña "Media": mezclador de volumen por dispositivo ---
                            Flickable {
                                id: mediaTabFlick
                                width: mediaTabContent.implicitWidth
                                height: carousel.height
                                contentHeight: mediaTabContent.implicitHeight
                                clip: true

                                Column {
                                    id: mediaTabContent
                                    width: 336
                                    VolumeMixer { width: parent.width }
                                }
                            }

                            // --- Pestaña "Performance": gauges de CPU/GPU/RAM (Hito 004 follow-up 8/9) ---
                            // Ya no se fuerza width:parent.width en
                            // PerformanceGauges — reporta su propio ancho
                            // natural (3 gauges + spacing generoso, ver
                            // PerformanceGauges.qml) para que esta pestaña
                            // también sea de las que ensanchan el panel (ver
                            // card.activeContentWidth case 3).
                            Flickable {
                                id: perfTabFlick
                                width: perfTabContent.implicitWidth
                                height: carousel.height
                                contentHeight: perfTabContent.implicitHeight
                                clip: true

                                Column {
                                    id: perfTabContent
                                    spacing: 12

                                    Text {
                                        text: "RENDIMIENTO"
                                        color: Theme.textMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    PerformanceGauges {}
                                }
                            }

                            // --- Pestaña "Workspaces": apps por workspace (Hito 004 follow-up 8) ---
                            Flickable {
                                id: wsTabFlick
                                width: wsTabContent.implicitWidth
                                height: carousel.height
                                contentHeight: wsTabContent.implicitHeight
                                clip: true

                                Column {
                                    id: wsTabContent
                                    width: 336
                                    spacing: 8

                                    Text {
                                        text: "WORKSPACES"
                                        color: Theme.textMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    WorkspacesOverview { width: parent.width }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
