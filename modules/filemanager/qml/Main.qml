// Hito 005 — Fase 2. Paso 5: pase de animación/glow (ver
// NIXOS_FILEMANAGER_HITO05_PLAN.md §4/§8). Primitivos Kirigami nativos
// donde existen, trabajo custom para lo que no tiene equivalente Kirigami
// (glow de proximidad, hover-scale, flash de apertura) — mismo criterio de
// duración/easing que Theme.qml de QuickShell (durFast/durMed/durSlow,
// easeOutCubic/OutBack/InOutQuad), redeclarado acá como constantes locales
// porque este es un proceso QML separado sin acceso al singleton de
// QuickShell (mismo motivo que forzó PaletteWatcher en el paso 3).
//
// Nota real sobre Kirigami.PageRow (el primitivo que el plan §4 recomendaba
// para la navegación, "vale la pena construir sobre PageRow en vez de
// reinventar breadcrumbs a mano"): SE INTENTÓ en esta sesión — cada
// entrada a una carpeta empujaba un Kirigami.Page nuevo con su propio
// FolderModel. Verificado en vivo con un self-test programático
// (folderPageRow.push()/pop() llamados directo, sin depender de clicks):
// el estado LÓGICO de PageRow es correcto (depth 1->2, currentItem.
// targetFolder cambia al valor esperado, pop() lo revierte bien — todo
// confirmado por consola). Pero el panel VISIBLE nunca cambiaba de
// contenido — screenshot real tras el push seguía mostrando el listado de
// $HOME, no el de la carpeta empujada, pese a que currentItem ya apuntaba
// a la nueva página. No se identificó la causa exacta en el tiempo
// disponible (sospecha: PageRow embebido angosto/sin columnas, fuera del
// pageStack nativo de ApplicationWindow, interactuando mal con su modelo
// de layout por columnas) — el plan (§7) ya anticipaba este riesgo
// explícito y autorizaba una salida: "tiene salida de emergencia
// (breadcrumb a mano + StackView) si no convence". Se tomó esa salida:
// esta versión final vuelve al modelo de navegación de los pasos 2-4 (un
// solo FolderModel compartido, reasignar `folder` in-place) — probado y
// visualmente confirmado funcionando en cada paso anterior — en vez de
// arriesgar una navegación rota pero "elegante" en el código. Queda como
// pendiente real para retomar en una sesión futura con más margen para
// diagnosticar PageRow a fondo (ver NIXOS_ARCHITECTURE_HITO_005.md §5).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.nixos.filemanager

Kirigami.ApplicationWindow {
    id: root
    title: "nixfm — " + folderModel.folder
    width: 1000
    height: 650
    visible: true

    // --- Mismas curvas que Theme.qml (modules/quickshell/services/Theme.qml)
    // — no son Kirigami.Units.*: se probó adoptarlas tal cual, pero la
    // continuidad visual 1:1 con el resto del sistema es el requisito
    // explícito de este hito (plan §4), así que se pisan acá en vez de
    // heredar los valores de fábrica de Kirigami.
    readonly property int durFast: 140
    readonly property int durMed: 240
    readonly property int durSlow: 420
    readonly property int easeOutCubic: Easing.OutCubic
    readonly property int easeOutBack: Easing.OutBack
    readonly property int easeInOutQuad: Easing.InOutQuad

    // Hallazgo real de esta ronda (follow-up post-Fase 2, ver
    // docs/NIXOS_ARCHITECTURE_HITO_005.md §8) — NO usar
    // `Kirigami.Theme.*` para pisar colores con este style activo:
    //
    // El intento original era pisar Kirigami.Theme.backgroundColor/
    // textColor/etc en la raíz (documentado en plan §3.1 como "alcanza con
    // fijar los colores una sola vez"). Verificado con un console.warn
    // temporal leyendo el valor de vuelta: el binding se evalúa
    // correctamente al toque (frame 0), pero milisegundos después el
    // backend real de "org.kde.desktop" (PlatformTheme, que lee
    // ~/.config/kdeglobals de verdad — el mismo archivo que instala
    // modules/kvantum/kdeglobals para Dolphin) lo PISA por su cuenta con
    // el color real del esquema oscuro del sistema — una asignación
    // imperativa que corta el binding declarativo para siempre. Esto NO
    // pasaba en ninguna verificación anterior (pasos 3 y 5, y el primer
    // intento de este follow-up en §6) porque el style todavía estaba
    // roto ("Basic", sin backend de PlatformTheme que compitiera) — o sea
    // que ni el acento/hover/focus de los pasos anteriores estaban
    // realmente pisados de forma confiable, solo lo PARECÍAN porque nada
    // los disputaba todavía.
    //
    // El fix real: `palette.*` (QPalette real de Qt, no la propiedad
    // adjunta de Kirigami) — confirmado ESTABLE con el mismo método
    // (leído de vuelta 1.5s después, no se resetea). Es el mecanismo que
    // controles nativos (StyleItem, ver ScrollView/ToolBar más abajo)
    // también respetan, así que un solo lugar cubre ambos casos. Todo lo
    // que este archivo pinta a mano (Rectangles propios) usa
    // paletteWatcher.* directo — ni Kirigami.Theme ni palette, la fuente
    // de verdad sin intermediarios.
    palette.window: paletteWatcher.background
    palette.windowText: paletteWatcher.text
    palette.base: paletteWatcher.background
    palette.alternateBase: paletteWatcher.surfaceVariant
    palette.text: paletteWatcher.text
    palette.button: paletteWatcher.surfaceVariant
    palette.buttonText: paletteWatcher.text
    palette.highlight: paletteWatcher.activeBackground
    palette.highlightedText: paletteWatcher.activeText
    palette.link: paletteWatcher.link
    palette.placeholderText: paletteWatcher.textMuted

    // Portapapeles de un solo elemento (paso 4).
    property url clipboardUrl: ""
    property bool clipboardCut: false

    function baseName(u) {
        return u.toString().replace(/\/$/, "").split("/").pop();
    }

    function joinPath(dirUrl, name) {
        return dirUrl.toString().replace(/\/$/, "") + "/" + name;
    }

    // --- Texto de los ToolButton (follow-up post-Fase 2, ver
    // docs/NIXOS_ARCHITECTURE_HITO_005.md §8): a diferencia de
    // ItemDelegate (donde "contentItem:" SÍ reemplaza el texto pintado
    // por el style), ToolButton.qml (qqc2-desktop-style) pinta el texto
    // DENTRO de su propio "background:" — un StylePrivate.StyleItem
    // nativo (elementType "toolbutton") al que se le pasa
    // `text: controlRoot.Kirigami.MnemonicData.mnemonicLabel`
    // directamente. Ese texto lo pinta QStyle vía Kirigami.Theme
    // internamente (roto, ver comentario grande en la raíz) SIN
    // importar qué contentItem propio se declare encima — confirmado
    // en vivo: un contentItem propio con color correcto no cambiaba
    // nada, el texto nativo (pálido, ilegible) seguía ahí debajo.
    // Fix real: forzar `display: IconOnly` para que el StyleItem NUNCA
    // pinte texto (solo el ícono, cuyo color de fallback si no hay
    // ícono en el tema tampoco nos importa acá), y agregar el label
    // como HERMANO aparte, pintado a mano con paletteWatcher — mismo
    // criterio que el resto del archivo. Un TapHandler en el label
    // reenvía el click al botón nativo (mantiene el chrome/hover real).
    component ToolButtonEntry: RowLayout {
        id: tbRow
        property string iconName
        property string label
        property bool buttonEnabled: true
        signal activated()
        spacing: Kirigami.Units.smallSpacing
        QQC2.ToolButton {
            icon.name: tbRow.iconName
            display: QQC2.AbstractButton.IconOnly
            enabled: tbRow.buttonEnabled
            onClicked: tbRow.activated()
        }
        QQC2.Label {
            text: tbRow.label
            color: tbRow.buttonEnabled ? paletteWatcher.text : paletteWatcher.textMuted
            TapHandler {
                enabled: tbRow.buttonEnabled
                onTapped: tbRow.activated()
            }
        }
    }

    PaletteWatcher {
        id: paletteWatcher
    }

    FolderModel {
        id: folderModel
    }

    PlacesModel {
        id: placesModel
    }

    FileOperations {
        id: fileOps
        onOperationSucceeded: (op) => statusLabel.text = "OK: " + op
        onOperationFailed: (op, msg) => statusLabel.text = "Error (" + op + "): " + msg
    }

    QQC2.Menu {
        id: contextMenu
        property url targetUrl
        property string targetName
        property bool targetIsDir

        QQC2.MenuItem {
            text: "Copiar"
            onTriggered: {
                root.clipboardUrl = contextMenu.targetUrl;
                root.clipboardCut = false;
            }
        }
        QQC2.MenuItem {
            text: "Cortar"
            onTriggered: {
                root.clipboardUrl = contextMenu.targetUrl;
                root.clipboardCut = true;
            }
        }
        QQC2.MenuItem {
            text: "Pegar en esta carpeta"
            enabled: root.clipboardUrl.toString().length > 0 && contextMenu.targetIsDir
            onTriggered: {
                const dest = root.joinPath(contextMenu.targetUrl, root.baseName(root.clipboardUrl));
                if (root.clipboardCut)
                    fileOps.movePath(root.clipboardUrl, dest);
                else
                    fileOps.copyPath(root.clipboardUrl, dest);
                root.clipboardUrl = "";
            }
        }
        QQC2.MenuItem {
            text: "Renombrar"
            onTriggered: {
                renameField.text = contextMenu.targetName;
                renameDialog.targetUrl = contextMenu.targetUrl;
                renameDialog.open();
            }
        }
        QQC2.MenuItem {
            text: "Mover a la papelera"
            onTriggered: fileOps.moveToTrash(contextMenu.targetUrl)
        }
        QQC2.MenuItem {
            text: "Eliminar permanentemente"
            onTriggered: fileOps.removePermanently(contextMenu.targetUrl)
        }
    }

    QQC2.Dialog {
        id: renameDialog
        property url targetUrl
        title: "Renombrar"
        modal: true
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        anchors.centerIn: parent

        QQC2.TextField {
            id: renameField
            implicitWidth: 260
        }

        onAccepted: {
            if (renameField.text.length === 0)
                return;
            const parentDir = renameDialog.targetUrl.toString().replace(/\/[^/]+\/?$/, "/");
            fileOps.movePath(renameDialog.targetUrl, parentDir + renameField.text);
        }
    }

    QQC2.Dialog {
        id: newFolderDialog
        title: "Nueva carpeta"
        modal: true
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        anchors.centerIn: parent
        onOpened: newFolderField.text = ""

        QQC2.TextField {
            id: newFolderField
            implicitWidth: 260
        }

        onAccepted: {
            if (newFolderField.text.length === 0)
                return;
            fileOps.makeDir(root.joinPath(folderModel.folder, newFolderField.text));
        }
    }

    // La barra de título automática de Kirigami (el "file:///..." que
    // mostraba antes) es Kirigami puro (ToolBarPageHeader.qml, no
    // StyleItem) pero también termina resolviendo sus colores contra el
    // PlatformTheme real (fuerza su propio Kirigami.Theme.colorSet:
    // Header) — mismo problema de fondo que el resto de este follow-up,
    // ver el comentario grande de arriba. En vez de perseguir un tercer
    // mecanismo para UN SOLO label de texto, se apaga la barra automática
    // y la ruta actual se muestra en el QQC2.ToolBar propio de más abajo
    // (que ya se pinta a mano) — un lugar menos con color no confiable.
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    pageStack.initialPage: Kirigami.Page {
        title: folderModel.folder.toString()
        padding: 0

        // Bug real encontrado en vivo, diagnosticado a fondo (follow-up
        // post-Fase 2, ver docs/NIXOS_ARCHITECTURE_HITO_005.md §8):
        // Kirigami.Theme.backgroundColor NO es confiable con el style
        // "org.kde.desktop" realmente activo — su PlatformTheme (lee
        // ~/.config/kdeglobals de verdad) pisa cualquier binding QML
        // apenas termina de cargar, cortándolo. Se pinta directo con
        // paletteWatcher.background (la fuente de verdad real, sin pasar
        // por Kirigami.Theme) — confirmado estable con un console.warn
        // temporal leído 1.5s después de arrancar.
        background: Rectangle {
            color: paletteWatcher.background
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // --- Sidebar de Places: KFilePlacesModel real ---
            QQC2.ScrollView {
                Layout.preferredWidth: 220
                Layout.fillHeight: true

                // Causa raíz real (leída directo del fuente de
                // qqc2-desktop-style, ScrollView.qml): su `background:` es
                // un StylePrivate.StyleItem — pintado por el motor nativo
                // de QStyle vía QPalette real del sistema, un mecanismo
                // COMPLETAMENTE SEPARADO de las propiedades adjuntas
                // Kirigami.Theme. Mismo fix que el resto: paletteWatcher
                // directo, sin intermediario.
                background: Rectangle {
                    color: paletteWatcher.surfaceVariant
                }

                ListView {
                    id: placesView
                    model: placesModel
                    delegate: QQC2.ItemDelegate {
                        id: placeDelegate
                        // Bug real encontrado en vivo (follow-up post-Fase 2,
                        // ver NIXOS_ARCHITECTURE_HITO_005.md §7): "Modified
                        // Today"/"Modified Yesterday" son bookmarks
                        // timeline:/today y timeline:/yesterday que Dolphin
                        // escribió en ~/.local/share/user-places.xbel (el
                        // archivo de places COMPARTIDO entre cualquier app
                        // KIO, no algo propio de nixfm) usando la plantilla
                        // de defaults de KDE — pero el protocolo "timeline"
                        // no existe en este kio-extras (confirmado: sin
                        // .so/.protocol en todo el closure, aparentemente
                        // reemplazado río arriba por "recentlyused", que sí
                        // está). Clickear estas dos entradas siempre falla
                        // ("couldn't create worker: Unknown protocol
                        // 'timeline'") y deja el panel vacío para siempre —
                        // no es arreglable desde acá (no podemos empaquetar
                        // un worker que no existe), así que se ocultan.
                        readonly property bool isBrokenTimeline: placesModel.url(placesModel.index(index, 0)).toString().indexOf("timeline:") === 0
                        visible: !isBrokenTimeline
                        height: isBrokenTimeline ? 0 : implicitHeight
                        width: placesView.width
                        text: model.display
                        // "icon.source: model.decoration" NO sirve — bug real
                        // encontrado en vivo (paso 4): model.decoration
                        // (Qt::DecorationRole) entrega un QIcon, icon.source
                        // es QUrl. KFilePlacesModel expone "iconName" (string)
                        // aparte, que sí calza con icon.name.
                        icon.name: model.iconName

                        // --- Selección real (follow-up post-Fase 2, ver
                        // docs/NIXOS_ARCHITECTURE_HITO_005.md §8): antes
                        // "highlighted" nunca se seteaba — no había forma de
                        // ver qué place está activo salvo leyendo el título
                        // de la ventana. `highlighted` sigue siendo la
                        // propiedad real de QQC2.ItemDelegate (Nativo, ver
                        // plan §4), lo custom acá es el halo/fondo de abajo.
                        highlighted: placesView.currentIndex === index

                        // Fondo hecho a mano en vez de heredar el del style
                        // (pedido explícito: "not a style property") — usa
                        // paletteWatcher directo (no Kirigami.Theme, ver
                        // comentario grande en la raíz del archivo), con
                        // transición de color real (Behavior on color), no
                        // un corte brusco entre estados.
                        background: Rectangle {
                            radius: 6
                            color: placeDelegate.highlighted
                                ? paletteWatcher.activeBackground
                                : (placeHover.hovered ? Qt.rgba(paletteWatcher.accent.r, paletteWatcher.accent.g, paletteWatcher.accent.b, 0.15) : "transparent")
                            Behavior on color {
                                ColorAnimation { duration: root.durFast }
                            }
                        }

                        // --- Halo de proximidad (mismo idiom que
                        // Capsule.qml de QuickShell: borde translúcido más
                        // grande que el ítem, opacity nunca instantánea) —
                        // más intenso si es el place seleccionado.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 9
                            color: "transparent"
                            border.width: 2
                            border.color: paletteWatcher.accent
                            z: -1
                            opacity: placeDelegate.highlighted ? 0.35 : (placeHover.hovered ? 0.18 : 0)
                            Behavior on opacity {
                                NumberAnimation { duration: root.durMed; easing.type: root.easeOutCubic }
                            }
                        }

                        // --- Hover-scale (paso 5) ---
                        scale: placeHover.hovered ? 1.02 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: root.durFast; easing.type: root.easeOutBack }
                        }
                        HoverHandler {
                            id: placeHover
                        }

                        // --- Texto real (follow-up post-Fase 2, ver
                        // docs/NIXOS_ARCHITECTURE_HITO_005.md §8): el
                        // contentItem por defecto de ItemDelegate.qml
                        // (qqc2-desktop-style) pinta su Label con
                        // Kirigami.Theme.textColor/highlightedTextColor a
                        // fuego, NUNCA control.palette.text — confirmado
                        // leyendo el fuente real del style. Como este
                        // archivo ya dejó de pisar Kirigami.Theme.* (ver
                        // comentario grande en la raíz), ese texto queda
                        // leyendo el color real del esquema oscuro del
                        // sistema sin modificar — casi blanco, invisible
                        // sobre nuestro fondo claro. Mismo fix que el resto:
                        // contentItem propio, paletteWatcher directo.
                        // Estructura calcada de la del style (mismo
                        // GridLayout, mismo tamaño dinámico vía
                        // placeDelegate.icon.width/height) — ver el mismo
                        // comentario en itemDelegate más abajo sobre por
                        // qué un tamaño fijo rompía la resolución del
                        // ícono real.
                        contentItem: GridLayout {
                            rows: 1
                            columns: 2
                            rowSpacing: placeDelegate.spacing
                            columnSpacing: placeDelegate.spacing
                            Kirigami.Icon {
                                selected: placeDelegate.highlighted || placeDelegate.down
                                Layout.preferredHeight: placeDelegate.icon.height
                                Layout.preferredWidth: placeDelegate.icon.width
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                visible: placeDelegate.icon.name.length > 0
                                source: placeDelegate.icon.name
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: placeDelegate.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                color: (placeDelegate.highlighted || placeDelegate.down) ? paletteWatcher.activeText : paletteWatcher.text
                            }
                        }

                        onClicked: {
                            placesView.currentIndex = index;
                            folderModel.folder = placesModel.url(placesModel.index(index, 0));
                        }
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillHeight: true
            }

            // --- Listado de la carpeta actual ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                QQC2.ToolBar {
                    Layout.fillWidth: true
                    // Mismo problema y mismo fix que el ScrollView de
                    // arriba: ToolBar.qml de qqc2-desktop-style pinta su
                    // fondo con Private.DefaultToolBarBackground (nativo,
                    // vía QPalette real) — paletteWatcher directo, sin
                    // pasar por Kirigami.Theme.
                    background: Rectangle {
                        color: paletteWatcher.surfaceVariant
                    }
                    RowLayout {
                        anchors.fill: parent
                        ToolButtonEntry {
                            iconName: "go-up"
                            label: "Subir"
                            onActivated: {
                                const parentUrl = folderModel.folder.toString().replace(/\/[^/]+\/?$/, "/");
                                folderModel.folder = parentUrl;
                            }
                        }
                        ToolButtonEntry {
                            iconName: "folder-new"
                            label: "Nueva carpeta"
                            onActivated: newFolderDialog.open()
                        }
                        ToolButtonEntry {
                            iconName: "edit-paste"
                            label: "Pegar"
                            buttonEnabled: root.clipboardUrl.toString().length > 0
                            onActivated: {
                                const dest = root.joinPath(folderModel.folder, root.baseName(root.clipboardUrl));
                                if (root.clipboardCut)
                                    fileOps.movePath(root.clipboardUrl, dest);
                                else
                                    fileOps.copyPath(root.clipboardUrl, dest);
                                root.clipboardUrl = "";
                            }
                        }
                        // Ruta actual — vivía en la barra de título
                        // automática de Kirigami, apagada más arriba
                        // (pageStack.globalToolBar.style: None) porque esa
                        // barra tampoco resolvía sus colores de forma
                        // confiable. Texto explícito acá en vez, mismo
                        // paletteWatcher.text que el resto.
                        QQC2.Label {
                            Layout.fillWidth: true
                            // Sin esto el Label nunca se achica por debajo
                            // de su ancho natural (gotcha real de
                            // QtQuick.Layouts: el mínimo implícito de un
                            // Text es su implicitWidth) — con una ruta
                            // larga esto empujaba el swatch de acento de
                            // más abajo fuera del borde visible de la
                            // ventana en vez de elidir. Confirmado en vivo
                            // con screenshot (swatch invisible).
                            Layout.minimumWidth: 0
                            Layout.leftMargin: 8
                            elide: Text.ElideMiddle
                            text: folderModel.folder.toString()
                            color: paletteWatcher.text
                        }
                        // Indicador del acento activo (paso 3) — sigue al
                        // workspace de Hyprland en vivo, sin relanzar la app.
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 9
                            color: paletteWatcher.accent
                            border.color: paletteWatcher.text
                            border.width: 1
                        }
                    }
                }

                ListView {
                    id: folderView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: folderModel

                    // --- Transición de navegación (follow-up post-Fase 5,
                    // ver docs/NIXOS_ARCHITECTURE_HITO_005.md §8): PageRow
                    // se revirtió por el bug real de §5.2 (el panel visible
                    // nunca cambiaba de contenido), pero eso no significa
                    // "sin transición al navegar" — un fundido corto cada
                    // vez que folderModel.folder cambia, mismo criterio de
                    // duración/easing que el resto de la app
                    // (durFast/durMed + easeOutCubic), sin necesitar
                    // PageRow ni ningún otro primitivo de navegación.
                    // SequentialAnimation imperativa a propósito, SIN
                    // "Behavior on opacity" al lado — mismo motivo que
                    // openFlash más abajo: combinar un Behavior con una
                    // animación imperativa sobre la misma propiedad del
                    // mismo objeto es justo el bug que ese comentario ya
                    // documenta para "scale".
                    SequentialAnimation {
                        id: navFade
                        NumberAnimation { target: folderView; property: "opacity"; to: 0.35; duration: root.durFast; easing.type: root.easeOutCubic }
                        NumberAnimation { target: folderView; property: "opacity"; to: 1.0; duration: root.durMed; easing.type: root.easeOutCubic }
                    }
                    Connections {
                        target: folderModel
                        function onFolderChanged() { navFade.restart(); }
                    }

                    delegate: Item {
                        id: delegateRoot
                        width: folderView.width
                        height: 40

                        // --- Fondo de selección (follow-up post-Fase 2):
                        // paletteWatcher.activeBackground directo (no
                        // Kirigami.Theme, ver comentario grande en la raíz
                        // del archivo), plano, con transición de color —
                        // pintado a mano en vez de dejárselo al style (ver
                        // itemDelegate.background más abajo, reemplazado a
                        // propósito).
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: itemDelegate.highlighted ? paletteWatcher.activeBackground : "transparent"
                            Behavior on color {
                                ColorAnimation { duration: root.durFast }
                            }
                        }

                        // --- Wash de hover (paso 5 original) — solo si el
                        // ítem no está ya seleccionado, para no competir
                        // visualmente con el fondo de arriba.
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            visible: !itemDelegate.highlighted
                            opacity: hoverHandler.hovered ? 0.45 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: root.durMed; easing.type: root.easeOutCubic }
                            }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(paletteWatcher.accent.r, paletteWatcher.accent.g, paletteWatcher.accent.b, 0.35) }
                                GradientStop { position: 1.0; color: Qt.rgba(paletteWatcher.accent.r, paletteWatcher.accent.g, paletteWatcher.accent.b, 0.0) }
                            }
                        }

                        // --- Halo de proximidad — sin equivalente
                        // Kirigami (100% custom, ver plan §4), mismo idiom
                        // de borde translúcido que Capsule.qml de
                        // QuickShell: más grande que el ítem, z:-1 para que
                        // quede detrás, opacity nunca instantánea. Más
                        // intenso si el ítem está seleccionado que si solo
                        // tiene el mouse encima.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 8
                            color: "transparent"
                            border.width: 2
                            border.color: paletteWatcher.accent
                            z: -1
                            opacity: itemDelegate.highlighted ? 0.4 : (hoverHandler.hovered ? 0.22 : 0)
                            Behavior on opacity {
                                NumberAnimation { duration: root.durMed; easing.type: root.easeOutCubic }
                            }
                        }

                        QQC2.ItemDelegate {
                            id: itemDelegate
                            anchors.fill: parent
                            text: model.name
                            icon.name: model.iconName
                            // El fondo real lo pintan los Rectangles de
                            // arriba (pedido explícito: hecho a mano, "not
                            // a style property") — un Item vacío evita que
                            // el style pinte otro fondo encima del nuestro.
                            background: Item {}
                            // Selección real (antes no existía ningún
                            // concepto de "ítem actual" en el listado de
                            // carpeta). highlighted sigue siendo la
                            // propiedad real de QQC2.ItemDelegate (nativo).
                            highlighted: folderView.currentIndex === index

                            // --- Texto real (follow-up post-Fase 2, ver
                            // docs/NIXOS_ARCHITECTURE_HITO_005.md §8): el
                            // contentItem por defecto de ItemDelegate.qml
                            // (qqc2-desktop-style) pinta su Label con
                            // Kirigami.Theme.textColor/highlightedTextColor
                            // a fuego (confirmado leyendo el fuente real
                            // del style — NUNCA control.palette.text/
                            // highlightedText, al revés de lo que decía el
                            // plan §4 y el comentario original acá). Como
                            // este archivo dejó de pisar Kirigami.Theme.*
                            // (ver comentario grande en la raíz), ese texto
                            // quedaba leyendo el color real del esquema
                            // oscuro del sistema sin modificar — casi
                            // blanco, invisible sobre nuestro fondo claro
                            // (confirmado en vivo con screenshot). Mismo
                            // fix que el resto: contentItem propio,
                            // paletteWatcher directo.
                            // Estructura calcada a propósito de la del
                            // style (mismo GridLayout, mismo binding
                            // dinámico de tamaño vía itemDelegate.icon.
                            // width/height) — la primera versión de este
                            // fix usaba un RowLayout con tamaño fijo
                            // (20x20) y rompía la resolución del ícono real
                            // (Breeze mostraba el ícono roto/placeholder en
                            // vez del folder a color, confirmado en vivo
                            // con screenshot). Único cambio real respecto
                            // al contentItem por defecto: el color del
                            // Label.
                            contentItem: GridLayout {
                                rows: 1
                                columns: 2
                                rowSpacing: itemDelegate.spacing
                                columnSpacing: itemDelegate.spacing
                                Kirigami.Icon {
                                    selected: itemDelegate.highlighted || itemDelegate.down
                                    Layout.preferredHeight: itemDelegate.icon.height
                                    Layout.preferredWidth: itemDelegate.icon.width
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                    visible: itemDelegate.icon.name.length > 0
                                    source: itemDelegate.icon.name
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: itemDelegate.text
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    color: (itemDelegate.highlighted || itemDelegate.down) ? paletteWatcher.activeText : paletteWatcher.text
                                }
                            }

                            // --- Hover-scale (paso 5) — mismo patrón que
                            // Bar.qml/Capsule.qml de QuickShell.
                            scale: hoverHandler.hovered ? 1.015 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: root.durFast; easing.type: root.easeOutBack }
                            }

                            HoverHandler {
                                id: hoverHandler
                            }

                            onClicked: {
                                folderView.currentIndex = index;
                                if (model.isDir) {
                                    folderModel.folder = model.url;
                                } else {
                                    // Apertura real (paso 5, no estaba en
                                    // ningún paso anterior — ver cabecera):
                                    // KIO::OpenUrlJob vía FileOperations,
                                    // misma xdg.mimeApps que ya declara
                                    // home.nix (plan §5.1).
                                    openFlash.start();
                                    fileOps.openFile(model.url);
                                }
                            }

                            // --- Flash de apertura (paso 5) — sin
                            // equivalente Kirigami. opacity en vez de scale
                            // a propósito: scale ya tiene un binding
                            // declarativo (hover, arriba) — animarlo acá con
                            // NumberAnimation imperativo lo rompería.
                            SequentialAnimation {
                                id: openFlash
                                NumberAnimation { target: itemDelegate; property: "opacity"; to: 0.4; duration: root.durFast; easing.type: root.easeOutCubic }
                                NumberAnimation { target: itemDelegate; property: "opacity"; to: 1.0; duration: root.durFast; easing.type: root.easeOutCubic }
                            }

                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: {
                                    contextMenu.targetUrl = model.url;
                                    contextMenu.targetName = model.name;
                                    contextMenu.targetIsDir = model.isDir;
                                    contextMenu.popup();
                                }
                            }
                        }
                    }
                }

                QQC2.Label {
                    id: statusLabel
                    Layout.fillWidth: true
                    Layout.margins: 6
                    elide: Text.ElideRight
                    color: paletteWatcher.text
                }
            }
        }
    }
}
