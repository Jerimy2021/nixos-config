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
import Qt.labs.settings
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

    // --- Colapso real de breadcrumb (fix, ver docs
    // /NIXOS_ARCHITECTURE_HITO_005.md §12): primer segmento + "…" +
    // últimos hasta-3, el "…" es un MenuItem-per-segmento-oculto (ver
    // breadcrumbEllipsisMenu más abajo), no solo un scroll horizontal
    // más. La decisión de SI colapsar (breadcrumbFlick.overflow) y el
    // tamaño de cola acá adentro usan el ancho REAL medido de cada pill
    // (`breadcrumbMeasureRepeater.itemAt(i).width`, ver measureRow en
    // el Flickable), no un estimado por cantidad de caracteres —
    // primer intento en vivo con cola fija en 3 dejó el primer
    // segmento ("Home") empujado casi entero fuera de vista en una
    // ventana angosta con nombres de carpeta largos, contradiciendo el
    // pedido explícito de "first segment ALWAYS visible" — acá la cola
    // se reduce 3→2→1 hasta que el candidato realmente entre en el
    // ancho disponible.
    function collapsedBreadcrumbSegments() {
        const all = root.breadcrumbSegments;
        if (all.length <= 2)
            return all;

        const sepWidth = 20; // ">" + spacing, aprox — measureRow no incluye separadores
        const ellipsisWidth = 34; // pill "…" sin ícono, angosta
        const available = breadcrumbFlick.width;
        const firstWidth = breadcrumbMeasureRepeater.count > 0 ? breadcrumbMeasureRepeater.itemAt(0).width : 80;

        for (let tail = Math.min(3, all.length - 1); tail >= 1; tail--) {
            const tailStart = all.length - tail;
            if (tailStart <= 1)
                continue; // cola = todo lo que hay después de "Home", nada que colapsar de verdad
            let tailWidth = 0;
            for (let i = tailStart; i < all.length; i++) {
                const item = breadcrumbMeasureRepeater.itemAt(i);
                tailWidth += (item ? item.width : 80) + sepWidth;
            }
            const candidateTotal = firstWidth + sepWidth + ellipsisWidth + sepWidth + tailWidth;
            if (candidateTotal <= available || tail === 1) {
                const hidden = all.slice(1, tailStart);
                if (hidden.length === 0)
                    return all;
                const result = [all[0], { label: "…", iconName: "", url: "", isEllipsis: true, hidden: hidden }];
                for (let i = tailStart; i < all.length; i++)
                    result.push(all[i]);
                return result;
            }
        }
        // Ni con cola=1 entra (nombre de la carpeta actual larguísimo,
        // más ancho que toda la ventana) — el auto-scroll-al-final del
        // Flickable (ver Connections en la fila de breadcrumb) es el
        // resguardo real para este caso extremo, no algo que valga la
        // pena resolver acá con más lógica.
        return all;
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

    // --- Colores de git status (feature 4, ver docs §11): literales fijos
    // a propósito, NO paletteWatcher — mismo criterio que los encabezados
    // de sección (fix, ver §11 también): rojo/verde/ámbar para git son una
    // convención universal (cualquier terminal, cualquier IDE, `git
    // status` con color), cambiarlos con el acento del workspace activo
    // rompería esa convención en vez de respetarla.
    function gitStatusColor(category) {
        switch (category) {
        case "conflict": return "#e5534b";
        case "staged": return "#3fb950";
        case "modified": return "#e0a030";
        case "untracked": return "#58a6ff";
        case "ignored": return "#8b8b8b";
        default: return "transparent";
        }
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
        // Feature 7 (toggle de ocultos, ver docs §11): extensión mínima
        // — checkable/checked en false por default, así los cinco usos
        // ya existentes (Subir/Nueva carpeta/Pegar/Terminal/Sidepad, ver
        // más abajo) quedan sin cambios de comportamiento. Cuando
        // checkable es true, el fondo del ToolButton nativo ya refleja
        // el estado (checked) con el mismo look que highlighted en el
        // resto del archivo — no hace falta reinventar un indicador
        // aparte.
        property bool checkable: false
        property bool checked: false
        signal activated()
        spacing: Kirigami.Units.smallSpacing
        // Fix (contraste real, ver docs §12): el pedido decía "increase
        // icon contrast/size" — el tamaño se puede agrandar de forma
        // confiable (20px en vez del default ~16px del style), pero el
        // COLOR del ícono no: el tema de ícono ACTIVO de este sistema es
        // Papirus-Dark (confirmado en vivo en ~/.config/qt6ct/qt6ct.conf,
        // icon_theme=Papirus-Dark — diseñado para fondos oscuros), y son
        // SVGs multicolor, no símbolos monocromos — `icon.color` no
        // tiene efecto sobre esos. Forzar todo el tema a "breeze" en
        // cambio SE INVESTIGÓ y se descartó — breeze no trae
        // "utilities-terminal" ni ningún ícono con "hidden" en el nombre
        // (comprobado con find sobre el theme instalado), así que el
        // swap habría arreglado 3 íconos pálidos a costa de dejar
        // Terminal/Ocultos sin ícono.
        //
        // Fix real: un chip de fondo detrás de CADA ícono. Primer
        // intento puesto directo en `ToolButton.background:` BORRÓ el
        // ícono por completo (confirmado en vivo con screenshot) — el
        // StyleItem nativo de qqc2-desktop-style que pinta el ÍCONO
        // vive DENTRO de ese mismo slot `background:` (mismo mecanismo
        // ya documentado en el comentario grande de arriba sobre el
        // texto — acá alcanzó también al ícono, no solo al texto).
        // Fix real: el chip va COMO HERMANO, detrás en z-order (Item
        // wrapper con el Rectangle primero, el ToolButton nativo
        // intacto encima, anchors.fill) — nunca se toca `background:`
        // del ToolButton, así el StyleItem nativo (ícono incluido)
        // sigue pintando exactamente igual que siempre.
        Item {
            implicitWidth: toolBtn.implicitWidth
            implicitHeight: toolBtn.implicitHeight
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: toolBtn.checked ? paletteWatcher.activeBackground : paletteWatcher.background
                border.width: 1
                border.color: toolBtn.checked ? paletteWatcher.accent : Qt.rgba(paletteWatcher.text.r, paletteWatcher.text.g, paletteWatcher.text.b, 0.18)
                opacity: toolBtn.enabled ? 1.0 : 0.5
            }
            QQC2.ToolButton {
                id: toolBtn
                anchors.fill: parent
                icon.name: tbRow.iconName
                icon.width: 20
                icon.height: 20
                display: QQC2.AbstractButton.IconOnly
                enabled: tbRow.buttonEnabled
                checkable: tbRow.checkable
                checked: tbRow.checked
                onClicked: tbRow.activated()
                // Fix (tooltips, ver docs §12): con display: IconOnly el
                // texto real vive en el QQC2.Label hermano de acá abajo,
                // no en el botón — sin esto, pasar el mouse sobre SOLO
                // el ícono (sin tocar el label) no mostraba ninguna
                // pista de qué hace el botón.
                QQC2.ToolTip.text: tbRow.label
                QQC2.ToolTip.visible: toolBtn.hovered
                QQC2.ToolTip.delay: 500
            }
        }
        QQC2.Label {
            text: tbRow.label
            color: tbRow.buttonEnabled ? paletteWatcher.text : paletteWatcher.textMuted
            font.bold: tbRow.checkable && tbRow.checked
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
        // Hito 005 §6 (migración final) — startupFolderArg es una
        // context property real de C++ (ver main.cpp), no una QML var
        // suelta: main.cpp parsea argv[1] (un path crudo o una URI
        // file://, QUrl::fromUserInput() no distingue a mano) ANTES de
        // cargar este módulo QML, así que ya está resuelta acá desde el
        // primer frame. Si viene vacía (el 99% de los lanzamientos —
        // SUPER+E, rofi drun, sin argumento) el constructor de
        // FolderModel ya dejó folder en Home por su cuenta, este
        // Component.onCompleted no hace nada. Necesario para que
        // Shortcuts.qml de QuickShell (dashboard, ver ese archivo) siga
        // pudiendo abrir una carpeta específica ahora que llama
        // `nixfm <ruta>` en vez de `dolphin <ruta>` — Dolphin soportaba
        // esto de fábrica, nixfm no tenía ningún manejo de argv antes.
        Component.onCompleted: {
            if (startupFolderArg.toString().length > 0)
                folderModel.folder = startupFolderArg;
        }
    }

    // Feature 7 (toggle de ocultos, ver docs §11): Qt.labs.settings —
    // persiste vía QSettings (formato INI real bajo
    // ~/.config/nixos/nixfm.conf, organización/nombre ya fijados en
    // main.cpp con QGuiApplication::setOrganizationName/setApplicationName)
    // sin escribir ninguna lectura/escritura de archivo a mano. `property
    // alias` ató directo al Q_PROPERTY real de FolderModel (mismo
    // showHiddenFiles que ya expone KCoreDirLister) — un solo dato, un
    // solo lugar de verdad, sin duplicar el bool acá.
    Settings {
        category: "filemanager"
        property alias showHiddenFiles: folderModel.showHiddenFiles
    }

    PlacesModel {
        id: placesModel
    }

    // Feature 4 (git status, ver docs §11): `folder` atado directo al
    // FolderModel real — cada navegación real (breadcrumb/sidebar/listado/
    // Subir) ya reasigna folderModel.folder, este binding declarativo
    // dispara el chequeo de git una sola vez por esos mismos eventos, sin
    // ningún Connections/onFolderChanged a mano.
    GitStatusModel {
        id: gitStatus
        folder: folderModel.folder
    }

    // Feature 8 (filtro rápido, ver docs §11): QSortFilterProxyModel
    // real (ver FolderFilterProxy.h) sentado ENCIMA de folderModel, no
    // una lista JS filtrada a mano — folderView pasa a apuntar acá (ver
    // más abajo) y hereda roleNames()/data() del FolderModel real sin
    // que ningún delegate necesite tocarse. Solo filtra lo que
    // FolderModel ya listó para la carpeta actual — nunca dispara un
    // listado nuevo ni busca en subcarpetas.
    FolderFilterProxy {
        id: filteredFolderModel
        sourceModel: folderModel
        filterText: filterField.text
    }

    FileOperations {
        id: fileOps
        onOperationSucceeded: (op) => statusLabel.text = "OK: " + op
        onOperationFailed: (op, msg) => statusLabel.text = "Error (" + op + "): " + msg
    }

    // --- Menú de segmentos ocultos del breadcrumb (fix, ver docs §12):
    // clickear el "…" (ver collapsedBreadcrumbSegments()) abre esto en
    // vez de expandir la fila entera in-line — revela específicamente
    // los segmentos escondidos, cada uno navega directo al click, mismo
    // patrón de Instantiator+Menu que ya usa este archivo en otro lado
    // (ver placesView más arriba para el section.delegate, aunque ahí
    // es ListView.section — acá es la primera vez que se arma un Menu
    // con contenido dinámico).
    QQC2.Menu {
        id: breadcrumbEllipsisMenu
        property var hiddenSegments: []
        Instantiator {
            model: breadcrumbEllipsisMenu.hiddenSegments
            delegate: QQC2.MenuItem {
                required property var modelData
                text: modelData.label
                onTriggered: folderModel.folder = modelData.url
            }
            onObjectAdded: (index, object) => breadcrumbEllipsisMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => breadcrumbEllipsisMenu.removeItem(object)
        }
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
        // Feature 5 (ver docs §11): copiar ruta vía wl-copy (mismo binario
        // que Súper+V/PRINT en keybinds.lua) — FileOperations.
        // copyAbsolutePath/copyRelativePath, ver ese archivo.
        QQC2.MenuItem {
            text: "Copiar ruta absoluta"
            onTriggered: fileOps.copyAbsolutePath(contextMenu.targetUrl)
        }
        QQC2.MenuItem {
            text: "Copiar ruta relativa (git)"
            onTriggered: fileOps.copyRelativePath(contextMenu.targetUrl)
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
                    // Fix (ver docs §12): mismo criterio que folderView
                    // más abajo — sin esto, el mismo scale de hover/
                    // selección de las filas del sidebar (ver más abajo)
                    // no tenía nada que lo recortara contra sus bounds.
                    clip: true
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
                        // Fix (pedido explícito, ver docs §11): ÚNICA
                        // excepción deliberada a "todo sigue el acento" en
                        // todo este archivo — un literal fijo, no
                        // paletteWatcher.*, a propósito NO cambia si
                        // cambia el workspace/acento activo. Todo lo demás
                        // (colores de carpeta, glow de selección, franja
                        // superior) sigue derivado en vivo como siempre.
                        color: "#1c140d"
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
                    // Fix (mapa mental, ver docs §12 — pedido explícito:
                    // "los iconos no se notan, no funciona el mapa
                    // mental, ordénalo"): cuatro clusters separados por
                    // Kirigami.Separator en vez de seis botones en fila
                    // sin ninguna jerarquía visual — navegación (Subir)
                    // | operaciones de archivo (Nueva carpeta/Pegar) |
                    // lanzadores externos (Terminal/Sidepad) | vista
                    // (Ocultos — Filtrar ya tiene su propia fila debajo,
                    // ver más abajo, así que acá solo va el toggle).
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
                        Kirigami.Separator {
                            Layout.fillHeight: true
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
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
                        Kirigami.Separator {
                            Layout.fillHeight: true
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                        }
                        // Feature 6 (ver docs §11): reusan foot/
                        // sidepad-toggle tal cual ya instalados
                        // (home.nix/scripts.nix), FileOperations solo les
                        // pasa la carpeta actual — nada de lanzar
                        // terminales se reimplementa acá.
                        ToolButtonEntry {
                            iconName: "utilities-terminal"
                            label: "Terminal aquí"
                            onActivated: fileOps.openTerminalHere(folderModel.folder)
                        }
                        ToolButtonEntry {
                            iconName: "view-right-new"
                            label: "Sidepad aquí"
                            onActivated: fileOps.openSidepadHere(folderModel.folder)
                        }
                        Kirigami.Separator {
                            Layout.fillHeight: true
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                        }
                        // Feature 7 (ver docs §11): toggle real, no una
                        // acción de un solo disparo — checkable/checked
                        // atados directo a folderModel.showHiddenFiles
                        // (KCoreDirLister, ver FolderModel.h/.cpp), la
                        // persistencia entre sesiones la maneja el
                        // Settings de más arriba, este botón solo refleja
                        // y cambia ese único valor.
                        ToolButtonEntry {
                            iconName: "show-hidden"
                            label: "Ocultos"
                            checkable: true
                            checked: folderModel.showHiddenFiles
                            onActivated: folderModel.showHiddenFiles = !folderModel.showHiddenFiles
                        }
                        // Espaciador — reemplaza al breadcrumb que vivía
                        // acá (fix, ver docs §12): el breadcrumb se movió
                        // a su propia fila de ancho completo debajo de
                        // este ToolBar (ver más abajo, "Fila de
                        // breadcrumb") porque compartir la barra de
                        // acciones con 6 botones lo dejaba sin espacio
                        // real para una ruta larga — pedido explícito del
                        // usuario. Este Item mantiene el swatch de acento
                        // pegado al borde derecho, mismo rol que
                        // Layout.fillWidth cumplía en el breadcrumb antes.
                        Item {
                            Layout.fillWidth: true
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

                // --- Fila de breadcrumb (fix, ver docs
                // /NIXOS_ARCHITECTURE_HITO_005.md §12): fila propia de
                // ancho completo, debajo del ToolBar de acciones y
                // encima del listado — mismo estilo/altura que la barra
                // de filtro (feature 8, §11) para que las dos lean como
                // parte del mismo header en capas, no paneles sueltos.
                // measureRow (invisible) mide el ancho REAL que ocuparía
                // la lista de segmentos COMPLETA (sin colapsar); si eso
                // no entra en el ancho disponible del Flickable, el
                // Repeater visible pasa a mostrar la versión colapsada
                // (root.collapsedBreadcrumbSegments(), ver función en la
                // raíz) en vez de confiar solo en el scroll horizontal
                // del Flickable — la decisión es sobre ancho MEDIDO, no
                // un estimado de píxeles por letra ni un umbral fijo de
                // cantidad de segmentos.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: paletteWatcher.surfaceVariant
                    Flickable {
                        id: breadcrumbFlick
                        // anchors.verticalCenter + height propia (NO
                        // anchors.fill) a propósito: height se fija al
                        // implicitHeight real de breadcrumbRow, así el
                        // Flickable mide exactamente su contenido y
                        // "centrado vertical en la barra de 36px" es
                        // un anchor normal contra el Rectangle padre —
                        // sin esto, `parent` DENTRO del Flickable es su
                        // contentItem (height = contentHeight =
                        // breadcrumbRow.implicitHeight), no el
                        // Rectangle de 36px, y centrar contra eso es
                        // una referencia circular que da y:0 siempre.
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        height: breadcrumbRow.implicitHeight
                        contentWidth: breadcrumbRow.implicitWidth
                        contentHeight: breadcrumbRow.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        // Auto-scroll al extremo derecho en cada
                        // navegación (fix, ver docs §12, encontrado en
                        // vivo navegando varios niveles con nombres
                        // largos): incluso YA colapsado, el resultado
                        // puede seguir sin entrar completo en el ancho
                        // disponible (nombres de carpeta largos) — sin
                        // esto el Flickable quedaba scrolleado a la
                        // IZQUIERDA por default, tapando justo el
                        // segmento actual (el más importante, el que
                        // tiene el pill resaltado) detrás del borde
                        // derecho de la ventana. Qt.callLater() a
                        // propósito: contentWidth todavía no reflejó el
                        // Repeater con los segmentos de la carpeta NUEVA
                        // en el mismo tick en que folderChanged se
                        // dispara — sin el callLater, este scroll usa el
                        // contentWidth de la carpeta ANTERIOR.
                        Connections {
                            target: folderModel
                            function onFolderChanged() {
                                Qt.callLater(function () {
                                    breadcrumbFlick.contentX = Math.max(0, breadcrumbFlick.contentWidth - breadcrumbFlick.width);
                                });
                            }
                        }
                        // Property calculada acá porque acá viven tanto
                        // measureRow como el width real disponible
                        // (width propio del Flickable) — ver comentario
                        // grande arriba.
                        readonly property bool overflow: measureRow.implicitWidth > width

                        Row {
                            id: measureRow
                            visible: false
                            spacing: 2
                            // id acá (feature del fix, ver
                            // collapsedBreadcrumbSegments() en la raíz):
                            // measureRepeater.itemAt(i).width da el ancho
                            // REAL de cada pill ya renderizado, no un
                            // estimado por cantidad de caracteres — eso
                            // es lo que permite reducir la cola del
                            // colapso (3→2→1) hasta que el resultado
                            // realmente entre, en vez de asumir que 3
                            // siempre alcanza.
                            Repeater {
                                id: breadcrumbMeasureRepeater
                                model: root.breadcrumbSegments
                                delegate: BreadcrumbPill {
                                    required property var modelData
                                    iconName: modelData.iconName
                                    label: modelData.label
                                }
                            }
                        }

                        Row {
                            id: breadcrumbRow
                            spacing: 2
                            readonly property var displaySegments: breadcrumbFlick.overflow ? root.collapsedBreadcrumbSegments() : root.breadcrumbSegments
                            Repeater {
                                model: breadcrumbRow.displaySegments
                                delegate: RowLayout {
                                    id: segmentRow
                                    required property var modelData
                                    required property int index
                                    spacing: 2
                                    BreadcrumbPill {
                                        iconName: segmentRow.modelData.iconName
                                        label: segmentRow.modelData.label
                                        isCurrent: segmentRow.index === breadcrumbRow.displaySegments.length - 1
                                        onActivated: {
                                            if (segmentRow.modelData.isEllipsis) {
                                                breadcrumbEllipsisMenu.hiddenSegments = segmentRow.modelData.hidden;
                                                breadcrumbEllipsisMenu.popup();
                                            } else {
                                                folderModel.folder = segmentRow.modelData.url;
                                            }
                                        }
                                    }
                                    QQC2.Label {
                                        visible: segmentRow.index < breadcrumbRow.displaySegments.length - 1
                                        text: ">"
                                        color: paletteWatcher.textMuted
                                    }
                                }
                            }
                        }
                    }
                }

                // Feature 8 (ver docs §11): barra de filtro propia en
                // vez de meter un campo más en el ToolBar de arriba, ya
                // apretado a los anchos de ventana angostos que se
                // probaron en la feature 6 — mismo `surfaceVariant` que
                // el ToolBar para que lea como parte del mismo header,
                // no un panel aparte.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: paletteWatcher.surfaceVariant
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 6
                        Kirigami.Icon {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: "search"
                            color: paletteWatcher.textMuted
                        }
                        QQC2.TextField {
                            id: filterField
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            placeholderText: "Filtrar en esta carpeta…"
                            background: null
                            color: paletteWatcher.text
                            placeholderTextColor: paletteWatcher.textMuted
                            // Convención fzf-style ya establecida en el
                            // resto del flujo de este usuario (rofi
                            // -dmenu, etc.): Escape limpia el filtro en
                            // vez de propagar y cerrar algo más.
                            Keys.onEscapePressed: filterField.clear()
                        }
                        // Contador de resultados (N visibles) — se apoya
                        // en ListView.count (folderView, ver más abajo),
                        // NO en un rowCount() de QAbstractItemModel
                        // llamado a mano: ese método no es una Q_PROPERTY
                        // con NOTIFY, así que un binding QML sobre él no
                        // se actualizaría solo al filtrar. count sí es
                        // una property real de ListView.
                        QQC2.Label {
                            visible: filterField.text.length > 0
                            text: folderView.count
                            color: paletteWatcher.textMuted
                        }
                    }
                    // Navegar a otra carpeta limpia el filtro — un
                    // filtro que sigue de "dev" a "Pictures" mostraría
                    // una lista vacía o resultados que no tienen que ver
                    // con nada, sin ninguna pista visible de por qué.
                    Connections {
                        target: folderModel
                        function onFolderChanged() {
                            filterField.clear();
                        }
                    }
                }

                ListView {
                    id: folderView
                    // Fix (ver docs §12, investigado a fondo antes de
                    // tocar nada — no se pudo reproducir un overflow
                    // dramático en un ícono estático de archivo probando
                    // .json/.yaml/.js reales, ni en hover, así que esto
                    // NO es el mismo bug que el de la costura de doble-
                    // borde de FolderIcon (§ronda anterior) — esa era
                    // una silueta pintada a mano con Rectangle+border,
                    // los archivos usan Kirigami.Icon (ícono real del
                    // sistema, otro camino de renderizado por completo,
                    // no puede compartir esa causa). Lo que SÍ se
                    // confirmó por inspección de código: este ListView
                    // (y placesView del sidebar) no tenían `clip: true`
                    // — QtQuick NO recorta el contenido de un Item por
                    // default, así que el `scale:` del hover/selección
                    // (1.015x–1.03x, ver más abajo) podía en principio
                    // dejar que el contenido de una fila se saliera de
                    // su banda hacia una fila vecina o el borde de la
                    // lista, sin nada que lo contuviera — una causa
                    // estructural real, aunque no se logró capturar un
                    // caso dramático en este entorno de prueba
                    // específico. Fix defensivo y correcto de cualquier
                    // forma: recortar la lista a sus propios bounds,
                    // mismo criterio que ya usan el resto de los
                    // Flickable de este archivo (breadcrumbFlick, etc).
                    clip: true
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: filteredFolderModel

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

                                    // --- Feature 4: badge de git status
                                    // (ver docs §11) — un lookup de mapa
                                    // por fila (gitStatus.statusMap ya
                                    // llegó una sola vez por carpeta
                                    // navegada, ver GitStatusModel.h),
                                    // nunca un `git status` por fila ni
                                    // por repintado. Afuera de un repo git
                                    // el mapa está vacío, el lookup da
                                    // undefined, la key cae en
                                    // gitStatusColor(undefined) ->
                                    // "transparent" -> invisible, sin
                                    // condicional aparte.
                                    Rectangle {
                                        readonly property string category: gitStatus.statusMap[model.name] || ""
                                        visible: gitStatus.isRepo && category.length > 0
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.rightMargin: -1
                                        anchors.bottomMargin: -1
                                        width: 9
                                        height: 9
                                        radius: 4.5
                                        color: root.gitStatusColor(category)
                                        border.width: 1
                                        border.color: paletteWatcher.background
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
