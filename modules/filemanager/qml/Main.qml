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
import QtQuick.Effects
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

    // Breadcrumb (fix, ver §11): property binding, no solo función suelta
    // — así se recalcula solo cada vez que folderModel.folder cambia,
    // QML trackea la dependencia igual aunque la lectura ocurra DENTRO
    // de la función llamada, no en la línea del binding.
    property var breadcrumbSegments: root.computeBreadcrumbSegments()

    function baseName(u) {
        return u.toString().replace(/\/$/, "").split("/").pop();
    }

    function joinPath(dirUrl, name) {
        return dirUrl.toString().replace(/\/$/, "") + "/" + name;
    }

    // --- Breadcrumb real (fix, ver docs/NIXOS_ARCHITECTURE_HITO_005.md
    // §11): reemplaza el Label de solo texto con la ruta file:// cruda.
    // Trabaja siempre sobre la forma YA CODIFICADA de toString() (la
    // misma que ya usaba el botón "Subir" — ver más abajo — para no
    // introducir un segundo esquema de encode/decode en el archivo);
    // decodeURIComponent() se aplica SOLO al label visible de cada
    // segmento, nunca a la URL que se le asigna de vuelta a
    // folderModel.folder. FolderModel.homeUrl (C++, nuevo — ver
    // FolderModel.h) le da a esta función un punto de referencia real
    // para poder mostrar "Home" en vez de listar /home/<user> a mano.
    // Fuera de $HOME (particiones, /, dispositivos del sidebar) el primer
    // segmento es "/" en vez de "Home".
    function computeBreadcrumbSegments() {
        const homeEnc = folderModel.homeUrl.toString().replace(/\/+$/, "");
        const curEnc = folderModel.folder.toString().replace(/\/+$/, "");
        const segments = [];
        let baseEnc, remainderEnc;
        if (curEnc === homeEnc || curEnc.startsWith(homeEnc + "/")) {
            baseEnc = homeEnc;
            remainderEnc = curEnc.slice(homeEnc.length);
            segments.push({ label: "Home", iconName: "user-home", url: homeEnc + "/" });
        } else {
            const m = curEnc.match(/^([a-z]+:\/\/)(.*)$/);
            const scheme = m ? m[1] : "file://";
            baseEnc = scheme.replace(/\/$/, "");
            remainderEnc = m ? m[2] : curEnc;
            segments.push({ label: "/", iconName: "folder", url: scheme + "/" });
        }
        const parts = remainderEnc.split("/").filter(p => p.length > 0);
        let acc = baseEnc;
        for (const part of parts) {
            acc += "/" + part;
            segments.push({ label: decodeURIComponent(part), iconName: "folder", url: acc + "/" });
        }
        return segments;
    }

    // --- Glow de carpeta (follow-up post-Fase 2, ver
    // docs/NIXOS_ARCHITECTURE_HITO_005.md §9): categorización REAL por
    // palabra clave en el nombre (no un hash) — el pedido ofrecía un
    // fallback más simple ("un solo gradiente para todas las carpetas")
    // si esto complicaba demasiado, pero clasificar por keyword resultó
    // igual de simple, así que se hizo. Los tres colores salen siempre de
    // paletteWatcher (roles reales derivados de matugen) — nunca hex fijo.
    // Como la paleta solo trae 8 roles de uso general (no cuatro roles
    // "gold/coral/berry/terracotta" dedicados), "terracota"/"baya" se
    // derivan con Qt.darker() de accent/link (una TRANSFORMACIÓN de un
    // color real, no un valor inventado aparte).
    function folderGlowColors(name) {
        const n = name.toLowerCase();
        if (/dev|code|proj|software|work/.test(n))
            return { a: paletteWatcher.accent, b: Qt.darker(paletteWatcher.accent, 1.45) }; // terracota
        if (/doc|reference|note|stud|univers|research/.test(n))
            return { a: paletteWatcher.link, b: Qt.darker(paletteWatcher.link, 1.3) }; // baya
        return { a: paletteWatcher.activeBackground, b: paletteWatcher.accent }; // oro (default)
    }

    // --- Agrupado real del sidebar (follow-up post-Fase 2, ver
    // docs/NIXOS_ARCHITECTURE_HITO_005.md §10): KFilePlacesModel YA trae
    // un rol "group" (GroupRole, ver kfileplacesmodel.h) con el nombre de
    // sección real de KDE ("Places"/"Remote"/"Devices"/etc, sin traducir
    // acá — este proceso no carga catálogos i18n) — no hizo falta
    // inventar una taxonomía propia ni tocar C++, sólo mapear esos
    // strings a las etiquetas en español que ya usa el resto de la UI.
    // "Recent"/"Recently Saved" mapea a "" a propósito: ese grupo en este
    // sistema son las dos bookmarks timeline:/ rotas (ver §7.2, ya
    // ocultas por completo) — sin esto, ListView.section.delegate
    // mostraría un encabezado "Recientes" flotando sobre una sección
    // vacía.
    function placeGroupLabel(raw) {
        switch (raw) {
        case "Places": return "Accesos";
        case "Remote": return "Red";
        case "Devices":
        case "Removable Devices": return "Sistema";
        case "Recent":
        case "Recently Saved": return "";
        case "Search For": return "Buscar";
        case "Tags": return "Etiquetas";
        default: return raw;
        }
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

    // --- Ícono de carpeta real, no un aura detrás del ícono del sistema
    // (follow-up post-Fase 2, ver docs/NIXOS_ARCHITECTURE_HITO_005.md
    // §10): pedido explícito del usuario tras ver el resultado de §9 —
    // "the icon itself needs to read as colored, not just have a colored
    // aura around a grey/blue system icon". Silueta de carpeta de dos
    // piezas (solapa + cuerpo) pintada a mano con dos Rectangle de radio
    // por esquina (Rectangle.topLeftRadius/etc — Qt 6.7+, disponible acá
    // en 6.11) en vez de QtQuick.Shapes/PathSvg: mismo resultado visual,
    // sin agregar un import ni un mecanismo nuevo a un archivo que ya
    // pinta todo lo demás con Rectangle a mano. La solapa queda sólida
    // (colorA) y el cuerpo lleva el gradiente real de dos stops
    // (colorA→colorB) — el mismo par que ya calculaba folderGlowColors()
    // para el aura de §9, ahora alimentando el RELLENO del ícono en vez
    // de (además de, ver más abajo) la sombra detrás.
    component FolderIcon: Item {
        id: folderIconRoot
        property color colorA: "#ffb77c"
        property color colorB: "#ffb77c"
        // Borde real (follow-up en vivo, mismo §10): a 22px y con la
        // familia "oro" (colorA/colorB muy cercanos entre sí Y cercanos
        // al fondo cálido de la fila), la silueta se perdía por completo
        // contra el halo borroso de iconGlowShape detrás — confirmado en
        // vivo con screenshot, se veía como un blob circular liso, no una
        // carpeta. Un trazo 1px con Qt.darker(colorB) le da un borde
        // definido que no depende de que colorA/colorB tengan contraste
        // entre sí ni contra lo que haya detrás.
        readonly property color strokeColor: Qt.darker(colorB, 1.35)

        // --- Fix "sticks out" (reportado por el usuario tras §10, en vivo
        // con crop+zoom de un solo ícono, ver docs §11): la solapa y el
        // cuerpo son dos Rectangle separados, cada uno con SU PROPIO
        // border de 1px. Antes la solapa se extendía hasta 0.38 (bien
        // adentro del cuerpo, que empieza en 0.26) — la mitad de esa
        // altura queda tapada por el cuerpo (dibujado después = encima),
        // pero el trazo de 1px de la solapa en ese tramo tapado SÍ se
        // veía asomando apenas por el borde derecho del cuerpo (la
        // solapa es más angosta, 52%, que el cuerpo, 100%), como un
        // segundo trazo/nudo saliendo del contorno principal —
        // confirmado visualmente en el crop, se leía como una pieza
        // rectangular de más "pegada" al borde, no una silueta limpia.
        // Fix real, dos partes: (1) la solapa ya NO se superpone con el
        // cuerpo — termina exactamente donde el cuerpo empieza (altura
        // 0.18, de 0.08 a 0.26) — nada que tapar; (2) la solapa pierde
        // su propio border — el cuerpo ya aporta el contorno visible de
        // toda la silueta, un segundo trazo en la solapa solo duplicaba
        // la línea justo en la costura y era la fuente real del "nudo".
        Rectangle {
            id: tab
            x: 0
            y: parent.height * 0.08
            width: parent.width * 0.52
            height: parent.height * 0.18
            topLeftRadius: Math.max(1, parent.width * 0.08)
            topRightRadius: Math.max(1, parent.width * 0.08)
            bottomLeftRadius: 0
            bottomRightRadius: 0
            color: folderIconRoot.colorA
        }

        Rectangle {
            id: body
            x: 0
            y: parent.height * 0.26
            width: parent.width
            height: parent.height * 0.66
            topLeftRadius: Math.max(1, parent.width * 0.05)
            topRightRadius: Math.max(1, parent.width * 0.14)
            bottomLeftRadius: Math.max(1, parent.width * 0.14)
            bottomRightRadius: Math.max(1, parent.width * 0.14)
            border.color: folderIconRoot.strokeColor
            border.width: 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: folderIconRoot.colorA }
                GradientStop { position: 1.0; color: folderIconRoot.colorB }
            }
        }
    }

    // --- Pill de breadcrumb (fix, ver docs/NIXOS_ARCHITECTURE_HITO_005.md
    // §11): reemplaza el Label de solo texto de la ruta cruda por
    // segmentos clickeables estilo "pill" — ícono + nombre, redondeado,
    // el segmento actual (isCurrent) resaltado con relleno + borde de
    // acento, el resto transparente salvo hover. Paleta siempre
    // paletteWatcher, mismo criterio que el resto del archivo.
    component BreadcrumbPill: Rectangle {
        id: pill
        property string iconName
        property string label
        property bool isCurrent: false
        signal activated()
        radius: height / 2
        implicitHeight: 24
        implicitWidth: pillContent.implicitWidth + 16
        color: pill.isCurrent ? paletteWatcher.activeBackground : (pillHover.hovered ? paletteWatcher.surfaceVariant : "transparent")
        border.width: pill.isCurrent ? 1 : 0
        border.color: paletteWatcher.accent
        Behavior on color {
            ColorAnimation { duration: root.durFast }
        }
        RowLayout {
            id: pillContent
            anchors.centerIn: parent
            spacing: 4
            Kirigami.Icon {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                source: pill.iconName
                selected: pill.isCurrent
            }
            QQC2.Label {
                text: pill.label
                font.bold: pill.isCurrent
                color: pill.isCurrent ? paletteWatcher.activeText : paletteWatcher.text
            }
        }
        HoverHandler {
            id: pillHover
        }
        TapHandler {
            onTapped: pill.activated()
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

                    // --- Agrupado real (follow-up post-Fase 2, ver
                    // docs/NIXOS_ARCHITECTURE_HITO_005.md §10): pedido
                    // explícito — encabezados de sección tipo
                    // "Accesos"/"Sistema" agrupando Home/Downloads/
                    // Pictures/Trash aparte de Network aparte de las
                    // particiones/discos, en vez de una lista plana.
                    // `section.property` es el primitivo NATIVO de
                    // ListView para esto — no hizo falta reinventar
                    // agrupado a mano (Repeater anidado, etc.):
                    // KFilePlacesModel ya expone el rol "group" (ver
                    // placeGroupLabel() en la raíz para el mapeo a
                    // español) y ya entrega los ítems ordenados por
                    // grupo, así que las secciones quedan contiguas de
                    // por sí.
                    section.property: "group"
                    section.criteria: ViewSection.FullString
                    section.delegate: QQC2.Label {
                        id: sectionLabel
                        required property string section
                        readonly property string label: root.placeGroupLabel(section)
                        width: placesView.width
                        // label vacío (grupo "Recent"/"Recently Saved" —
                        // ver placeGroupLabel) colapsa el encabezado en
                        // vez de mostrar un título sobre una sección
                        // vacía (las dos bookmarks timeline:/ rotas de
                        // §7.2, ya ocultas por completo más abajo).
                        visible: label.length > 0
                        height: label.length > 0 ? implicitHeight : 0
                        topPadding: 14
                        bottomPadding: 4
                        leftPadding: 12
                        text: label
                        font.pixelSize: 11
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.5
                        color: paletteWatcher.accent
                    }

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

                        // --- Elevación real (follow-up post-Fase 2, ver
                        // docs/NIXOS_ARCHITECTURE_HITO_005.md §9): antes
                        // esto era un borde translúcido fino (Rectangle
                        // solo con border, sin desenfoque) — pedido
                        // explícito: "colored box-shadow bleeding out from
                        // the accent, not just a background fill".
                        // Reemplazado por un blur real vía MultiEffect
                        // (QtQuick.Effects — Kirigami no trae nada
                        // parecido "out of the box", mismo criterio que el
                        // resto del proyecto: se construye a mano).
                        //
                        // Dos bugs reales encontrados en vivo con
                        // screenshot antes de llegar a esta versión (ver
                        // docs §9 para el detalle completo):
                        // 1. `shadowBlur` en escala 0..1 de MultiEffect
                        //    mapea a un radio bastante más grande de lo
                        //    esperable para un ítem de 40px — con 0.7-0.8
                        //    el halo de una fila se mezclaba con las
                        //    vecinas. 0.18 lo mantiene proporcional.
                        // 2. Más importante: `MultiEffect.source` renderiza
                        //    su pase principal (una copia nítida, sin
                        //    blur, de la fuente) IGNORANDO la opacity/
                        //    visible DEL ITEM FUENTE — confirmado en vivo
                        //    probando `visible: false` en placeShadowShape
                        //    y viendo que el bloque sólido seguía ahí
                        //    igual. La fuente, al ser usada como `source`
                        //    de un efecto, se cachea vía layering interno
                        //    de Qt Quick — ese layering ignora el opacity/
                        //    visible normal del item porque el efecto
                        //    necesita los píxeles para poder procesarlos,
                        //    sin importar si el item "debería" verse.
                        // Fix real: la fuente queda SIEMPRE sólida/visible
                        // (color fijo, sin condicional), y el control de
                        // intensidad se mueve a `MultiEffect.opacity` — una
                        // propiedad normal de Item, sin el problema de
                        // arriba porque no es la fuente cacheada, es la
                        // salida final del efecto. `MultiEffect.opacity`
                        // (con Behavior) anima el pase principal Y la
                        // sombra juntos, de forma confiable. La fuente en
                        // sí también se esconde (visible booleano, sin
                        // Behavior propio — no hace falta, lo que el ojo
                        // percibe lo anima el Behavior del MultiEffect de
                        // abajo, no este) para que su copia sólida no
                        // quede pegada permanentemente detrás cuando no
                        // hay nada opaco encima que la tape (fila en
                        // reposo, sin selección ni hover).
                        Rectangle {
                            id: placeShadowShape
                            anchors.fill: parent
                            radius: 6
                            color: paletteWatcher.accent
                            z: -1
                            visible: placeDelegate.highlighted || placeHover.hovered
                        }
                        MultiEffect {
                            anchors.fill: placeShadowShape
                            source: placeShadowShape
                            z: -1
                            opacity: placeDelegate.highlighted ? 0.85 : (placeHover.hovered ? 0.4 : 0.0)
                            shadowEnabled: true
                            shadowColor: paletteWatcher.accent
                            shadowBlur: 0.18
                            shadowVerticalOffset: 1
                            Behavior on opacity {
                                NumberAnimation { duration: root.durMed; easing.type: root.easeOutCubic }
                            }
                        }

                        // --- Hover-scale (paso 5) — extendido esta ronda
                        // para incluir el estado seleccionado, no solo
                        // hover ("slight scale-up on the selected/hot
                        // item", pedido explícito).
                        scale: placeDelegate.highlighted ? 1.02 : (placeHover.hovered ? 1.015 : 1.0)
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
                        // confiable. Fix (ver docs §11): el Label de solo
                        // texto con la URL file:// cruda se reemplazó por
                        // un breadcrumb real de pills clickeables
                        // (root.breadcrumbSegments, ver función y
                        // componente BreadcrumbPill arriba). Sigue siendo
                        // un Flickable, no un Row directo, por el MISMO
                        // gotcha que tenía el Label (el mínimo implícito
                        // de un item de ancho fijo empuja el swatch de
                        // acento fuera de la ventana en vez de recortar)
                        // — acá Layout.minimumWidth: 0 + clip: true en el
                        // Flickable cumplen el mismo rol que elide
                        // cumplía en el Label.
                        Flickable {
                            id: breadcrumbFlick
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.leftMargin: 8
                            Layout.preferredHeight: breadcrumbRow.implicitHeight
                            contentWidth: breadcrumbRow.implicitWidth
                            contentHeight: breadcrumbRow.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: breadcrumbRow
                                spacing: 2
                                Repeater {
                                    model: root.breadcrumbSegments
                                    delegate: RowLayout {
                                        id: segmentRow
                                        required property var modelData
                                        required property int index
                                        spacing: 2
                                        BreadcrumbPill {
                                            iconName: segmentRow.modelData.iconName
                                            label: segmentRow.modelData.label
                                            isCurrent: segmentRow.index === root.breadcrumbSegments.length - 1
                                            onActivated: folderModel.folder = segmentRow.modelData.url
                                        }
                                        QQC2.Label {
                                            visible: segmentRow.index < root.breadcrumbSegments.length - 1
                                            text: ">"
                                            color: paletteWatcher.textMuted
                                        }
                                    }
                                }
                            }
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

                        // --- Elevación real (follow-up post-Fase 2, ver
                        // docs/NIXOS_ARCHITECTURE_HITO_005.md §9) —
                        // reemplaza el halo de solo-borde de antes por un
                        // blur real vía MultiEffect. Mismo mecanismo y
                        // mismos bugs/fixes reales que placeDelegate en el
                        // sidebar (ver ese comentario para el detalle
                        // completo): blur desproporcionado para un ítem de
                        // 40px, y — el bug real — MultiEffect ignora la
                        // opacity de su `source` para el pase principal
                        // (confirmado en vivo). Fix: `MultiEffect.opacity`
                        // (con Behavior) anima el pase principal + sombra
                        // de forma confiable; la fuente además se esconde
                        // con un `visible` booleano simple (sin Behavior
                        // propio, no hace falta) para que su copia sólida
                        // no quede pegada detrás en reposo, sin nada
                        // opaco encima que la tape. Más intensa si el
                        // ítem está seleccionado que si solo tiene el
                        // mouse encima.
                        Rectangle {
                            id: cardShadowShape
                            anchors.fill: parent
                            radius: 8
                            color: paletteWatcher.accent
                            z: -1
                            visible: itemDelegate.highlighted || hoverHandler.hovered
                        }
                        MultiEffect {
                            anchors.fill: cardShadowShape
                            source: cardShadowShape
                            z: -1
                            opacity: itemDelegate.highlighted ? 0.5 : (hoverHandler.hovered ? 0.26 : 0.0)
                            shadowEnabled: true
                            shadowColor: paletteWatcher.accent
                            shadowBlur: 0.18
                            shadowVerticalOffset: 2
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
                                // Wrapper agregado esta ronda SOLO para
                                // poder meter el glow detrás del ícono sin
                                // tocar el tamaño/binding del Kirigami.Icon
                                // real — Layout.preferredWidth/Height siguen
                                // siendo itemDelegate.icon.width/height
                                // dinámico (la lección de la ronda pasada:
                                // un tamaño fijo rompía la resolución del
                                // ícono, ver comentario grande arriba).
                                Item {
                                    id: iconSlot
                                    Layout.preferredHeight: itemDelegate.icon.height
                                    Layout.preferredWidth: itemDelegate.icon.width
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                                    // Colores solo para carpetas (pedido
                                    // explícito: "folder icons" — los
                                    // archivos sueltos no llevan esta
                                    // categorización, se quedan con su
                                    // ícono real sin glow agregado).
                                    readonly property var glow: model.isDir ? root.folderGlowColors(model.name) : null

                                    // --- Glow de carpeta (pedido
                                    // explícito, ver docs §9): gradiente +
                                    // drop-shadow reales detrás del ícono
                                    // vía MultiEffect. A propósito NO se
                                    // re-colorea el ícono real
                                    // (Kirigami.Icon.color/isMask) — la
                                    // ronda anterior encontró en vivo que
                                    // tocar eso rompe la resolución del
                                    // ícono de Breeze y lo reemplaza por un
                                    // placeholder roto (ver §8.3 punto 2).
                                    // En cambio: un blob con gradiente
                                    // cálido detrás, desenfocado — su
                                    // núcleo nítido queda tapado por el
                                    // ícono real de encima (declarado
                                    // después = pinta arriba), solo el
                                    // desenfoque bordeando el ícono queda
                                    // visible.
                                    //
                                    // Bug real encontrado en vivo con
                                    // screenshot (mismo para los otros dos
                                    // usos de MultiEffect en este archivo,
                                    // ver el comentario completo en
                                    // placeShadowShape del sidebar): el
                                    // pase principal de MultiEffect ignora
                                    // la opacity DEL ITEM FUENTE — probado
                                    // con `visible:false` en este mismo
                                    // Rectangle y el glow seguía ahí igual,
                                    // fila tras fila, sumando hasta verse
                                    // como un bloque sólido en todo el
                                    // listado. Fix: DOS Behaviors
                                    // separados con la misma expresión —
                                    // uno acá (controla el anillo que se
                                    // ve directo, alrededor del ícono real,
                                    // ya que la opacity de un item SÍ
                                    // aplica normal a su propio render en
                                    // pantalla) y otro en el
                                    // `MultiEffect.opacity` de abajo
                                    // (controla el desenfoque/sombra, que
                                    // no hereda del primero por el bug de
                                    // arriba). Para archivos sueltos
                                    // (iconSlot.glow === null) ambos stops
                                    // del gradiente son "transparent" —
                                    // eso SÍ funciona sin importar la
                                    // opacity, porque es alpha de píxel,
                                    // no opacity de item. Opacity base
                                    // > 0 (no 0) a propósito — pedido
                                    // explícito: "read as glowing softly"
                                    // incluso en reposo, no solo al pasar
                                    // el mouse.
                                    // Re-ajustado esta ronda (§10, en vivo con
                                    // screenshot): con FolderIcon encima ya
                                    // pintando el color real del ícono, este
                                    // anillo full-size (margins:-2, radius
                                    // width/2, hasta 0.6 de opacity) quedaba
                                    // tan grande y tan cerca en tono a
                                    // colorA/colorB del ícono que se comía la
                                    // silueta entera — el resultado se veía
                                    // como un blob circular liso, no una
                                    // carpeta (confirmado: mismo bug para
                                    // "oro" default, donde colorA/colorB ya
                                    // son parecidos entre sí). Se encoge
                                    // (margins positivo, adentro del ícono en
                                    // vez de por fuera) y se baja la opacity a
                                    // la mitad — sigue dando un halo de
                                    // profundidad detrás del borde de
                                    // FolderIcon, ya no compite con él.
                                    Rectangle {
                                        id: iconGlowShape
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: width / 2
                                        opacity: itemDelegate.highlighted ? 0.3 : (hoverHandler.hovered ? 0.22 : 0.15)
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: iconSlot.glow ? iconSlot.glow.a : "transparent" }
                                            GradientStop { position: 1.0; color: iconSlot.glow ? iconSlot.glow.b : "transparent" }
                                        }
                                        Behavior on opacity {
                                            NumberAnimation { duration: root.durMed; easing.type: root.easeOutCubic }
                                        }
                                    }
                                    MultiEffect {
                                        anchors.fill: iconGlowShape
                                        source: iconGlowShape
                                        visible: iconSlot.glow !== null
                                        opacity: itemDelegate.highlighted ? 0.5 : (hoverHandler.hovered ? 0.38 : 0.26)
                                        shadowEnabled: true
                                        shadowColor: iconSlot.glow ? iconSlot.glow.a : "transparent"
                                        // Blur chico a propósito — acá el
                                        // "ítem" es el ícono de ~22px,
                                        // mucho más chico que las filas de
                                        // 40px de cardShadowShape/
                                        // placeShadowShape, así que
                                        // necesita un radio todavía más
                                        // contenido para no bleedear sobre
                                        // las filas vecinas.
                                        shadowBlur: 0.15
                                        shadowVerticalOffset: 1
                                        Behavior on opacity {
                                            NumberAnimation { duration: root.durMed; easing.type: root.easeOutCubic }
                                        }
                                    }
                                    // --- Ícono real de carpeta, no el del
                                    // sistema (follow-up post-Fase 2, ver
                                    // docs/NIXOS_ARCHITECTURE_HITO_005.md
                                    // §10): el gap real que quedaba de §9
                                    // — el ícono de Breeze (gris/azul,
                                    // "unmodified system icon") seguía
                                    // ahí, solo con un aura de color
                                    // detrás. Para carpetas (iconSlot.glow
                                    // !== null) se reemplaza por completo
                                    // por FolderIcon, coloreado con el
                                    // mismo par a/b de folderGlowColors()
                                    // que ya alimentaba el aura de arriba
                                    // — ahora el RELLENO real del ícono
                                    // lee como color de verdad, no gris
                                    // con un halo. Para archivos sueltos
                                    // (glow === null) se mantiene el ícono
                                    // real del sistema sin tocar — igual
                                    // que siempre.
                                    FolderIcon {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        visible: iconSlot.glow !== null
                                        colorA: iconSlot.glow ? iconSlot.glow.a : "transparent"
                                        colorB: iconSlot.glow ? iconSlot.glow.b : "transparent"
                                    }
                                    Kirigami.Icon {
                                        anchors.fill: parent
                                        selected: itemDelegate.highlighted || itemDelegate.down
                                        visible: iconSlot.glow === null && itemDelegate.icon.name.length > 0
                                        source: itemDelegate.icon.name
                                    }
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

                            // --- Hover-scale (paso 5) — extendido esta
                            // ronda para incluir el estado seleccionado,
                            // no solo hover ("slight scale-up on the
                            // selected/hot item", pedido explícito). Mismo
                            // patrón que Bar.qml/Capsule.qml de QuickShell.
                            scale: itemDelegate.highlighted ? 1.03 : (hoverHandler.hovered ? 1.015 : 1.0)
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

    // --- Franja de acento superior (pedido explícito, ver
    // docs/NIXOS_ARCHITECTURE_HITO_005.md §9): barra de 3px con gradiente
    // cálido cruzando todo el ancho de la ventana, mismo idiom que
    // ".panel::before" del mockup aprobado (hito05-filemanager-mockup.html
    // — ya no accesible en esta sesión, se sigue la descripción textual
    // del pedido). Hijo directo de `root`: QQC2.ApplicationWindow
    // reparenta los hijos declarados así dentro de `contentItem` (ver
    // AbstractApplicationWindow.qml de Kirigami — mismo mecanismo que ya
    // usan QQC2.Menu/QQC2.Dialog más arriba), por eso alcanza con anclar a
    // `parent` sin buscar un contentItem explícito. z alto a propósito:
    // tiene que quedar SIEMPRE arriba del pageStack, sin importar el
    // orden de declaración real dentro de contentItem.
    //
    // Colores: paletteWatcher.* directo, sin hex fijo — dos de los cuatro
    // stops son Qt.darker() de accent/activeBackground porque la paleta
    // de 8 roles no trae cuatro tonos "gold/coral/berry/terracotta"
    // dedicados (sigue siendo una TRANSFORMACIÓN de un rol real, no un
    // color inventado aparte). Behavior en cada stop — si el workspace
    // activo cambia de wallpaper/acento en vivo, la franja funde el color
    // nuevo en vez de saltar de golpe (mismo criterio de motion que el
    // resto del archivo).
    Rectangle {
        id: topAccentStripe
        z: 1000
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 3
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: paletteWatcher.link // "oro"
                Behavior on color { ColorAnimation { duration: root.durSlow } }
            }
            GradientStop {
                position: 0.38
                color: paletteWatcher.accent // "coral"
                Behavior on color { ColorAnimation { duration: root.durSlow } }
            }
            GradientStop {
                position: 0.68
                color: Qt.darker(paletteWatcher.accent, 1.4) // "baya" — derivado del acento real
                Behavior on color { ColorAnimation { duration: root.durSlow } }
            }
            GradientStop {
                position: 1.0
                color: Qt.darker(paletteWatcher.activeBackground, 1.3) // "terracota" — derivado del contenedor real
                Behavior on color { ColorAnimation { duration: root.durSlow } }
            }
        }
    }
}
