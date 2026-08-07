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

    // Hito 005, paso 3: Kirigami.Theme es una propiedad adjunta que se
    // hereda por todo el árbol QML hijo — pisarla acá en la raíz alcanza.
    // accentColor sigue al workspace activo de Hyprland/QuickShell vía
    // PaletteWatcher (archivo compartido, ver PaletteWatcher.cpp).
    Kirigami.Theme.highlightColor: paletteWatcher.accent
    Kirigami.Theme.focusColor: paletteWatcher.accent
    Kirigami.Theme.hoverColor: Qt.rgba(paletteWatcher.accent.r, paletteWatcher.accent.g, paletteWatcher.accent.b, 0.15)

    // Portapapeles de un solo elemento (paso 4).
    property url clipboardUrl: ""
    property bool clipboardCut: false

    function baseName(u) {
        return u.toString().replace(/\/$/, "").split("/").pop();
    }

    function joinPath(dirUrl, name) {
        return dirUrl.toString().replace(/\/$/, "") + "/" + name;
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

    pageStack.initialPage: Kirigami.Page {
        title: folderModel.folder.toString()
        padding: 0

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // --- Sidebar de Places: KFilePlacesModel real ---
            QQC2.ScrollView {
                Layout.preferredWidth: 220
                Layout.fillHeight: true

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

                        // --- Hover-scale (paso 5) ---
                        scale: placeHover.hovered ? 1.02 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: root.durFast; easing.type: root.easeOutBack }
                        }
                        HoverHandler {
                            id: placeHover
                        }

                        onClicked: folderModel.folder = placesModel.url(placesModel.index(index, 0))
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
                    RowLayout {
                        anchors.fill: parent
                        QQC2.ToolButton {
                            icon.name: "go-up"
                            text: "Subir"
                            onClicked: {
                                const parentUrl = folderModel.folder.toString().replace(/\/[^/]+\/?$/, "/");
                                folderModel.folder = parentUrl;
                            }
                        }
                        QQC2.ToolButton {
                            icon.name: "folder-new"
                            text: "Nueva carpeta"
                            onClicked: newFolderDialog.open()
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-paste"
                            text: "Pegar"
                            enabled: root.clipboardUrl.toString().length > 0
                            onClicked: {
                                const dest = root.joinPath(folderModel.folder, root.baseName(root.clipboardUrl));
                                if (root.clipboardCut)
                                    fileOps.movePath(root.clipboardUrl, dest);
                                else
                                    fileOps.copyPath(root.clipboardUrl, dest);
                                root.clipboardUrl = "";
                            }
                        }
                        Item { Layout.fillWidth: true }
                        // Indicador del acento activo (paso 3) — sigue al
                        // workspace de Hyprland en vivo, sin relanzar la app.
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 9
                            color: paletteWatcher.accent
                            border.color: Kirigami.Theme.textColor
                            border.width: 1
                        }
                    }
                }

                ListView {
                    id: folderView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: folderModel
                    delegate: Item {
                        id: delegateRoot
                        width: folderView.width
                        height: 40

                        // --- Glow de proximidad (paso 5) — sin equivalente
                        // Kirigami, mismo efecto (gradiente detrás del ítem)
                        // que usa QuickShell en Capsule.qml, portado acá.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: 8
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

                        QQC2.ItemDelegate {
                            id: itemDelegate
                            anchors.fill: parent
                            text: model.name
                            icon.name: model.iconName

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
                    color: Kirigami.Theme.textColor
                }
            }
        }
    }
}
