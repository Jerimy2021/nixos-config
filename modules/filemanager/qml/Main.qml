// Hito 005 — Fase 2. Paso 4: operaciones de archivo (copiar/mover/
// renombrar/crear carpeta/eliminar/papelera) vía FileOperations.cpp (ver
// NIXOS_FILEMANAGER_HITO05_PLAN.md §5.1 — kioclient no existe en este
// nixpkgs, esto usa coreutils + un script de papelera propio en su lugar).
// PageRow/animación llegan en el paso 5 — el menú contextual de acá es
// deliberadamente QQC2 plano, sin transición, igual que el resto de esta
// UI hasta ahora.
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

    // Hito 005, paso 3 (ver NIXOS_FILEMANAGER_HITO05_PLAN.md §3): pisar acá,
    // en la raíz, alcanza — Kirigami.Theme es una propiedad adjunta que se
    // hereda por todo el árbol QML hijo salvo que algún componente la pise
    // de nuevo más abajo. accentColor sigue al workspace activo de
    // Hyprland/QuickShell vía PaletteWatcher (archivo compartido, ver
    // PaletteWatcher.cpp) — no un color fijo.
    Kirigami.Theme.highlightColor: paletteWatcher.accent
    Kirigami.Theme.focusColor: paletteWatcher.accent
    Kirigami.Theme.hoverColor: Qt.rgba(paletteWatcher.accent.r, paletteWatcher.accent.g, paletteWatcher.accent.b, 0.15)

    // Portapapeles de un solo elemento (paso 4) — copiar/cortar un ítem,
    // pegar en la carpeta actual o sobre otra carpeta del listado.
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

    // Menú contextual compartido — un solo QQC2.Menu reusado por todos los
    // delegates del listado, con el target seteado justo antes de popup().
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

            // --- Sidebar de Places: KFilePlacesModel real, el mismo que
            // usan Dolphin y los diálogos nativos de KDE (ver plan §5.1) ---
            QQC2.ScrollView {
                Layout.preferredWidth: 220
                Layout.fillHeight: true

                ListView {
                    id: placesView
                    model: placesModel
                    delegate: QQC2.ItemDelegate {
                        width: placesView.width
                        text: model.display
                        // "icon.source: model.decoration" NO sirve — bug real
                        // encontrado en vivo: model.decoration (Qt::DecorationRole)
                        // entrega un QIcon, pero icon.source es una propiedad QUrl —
                        // QML lo rechaza en tiempo de ejecución ("Unable to assign
                        // QIcon to QUrl", sin crashear, pero sin ícono tampoco).
                        // KFilePlacesModel expone un role "iconName" (string) aparte,
                        // que sí calza con icon.name.
                        icon.name: model.iconName
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
                        // workspace de Hyprland en vivo, sin relanzar la
                        // app. Doble función: feedback visual real de
                        // "estoy temeado igual que el resto del sistema" +
                        // forma directa de verificar el paso 3 con una
                        // captura de pantalla.
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
                    delegate: QQC2.ItemDelegate {
                        id: fileDelegate
                        width: folderView.width
                        text: model.name
                        icon.name: model.iconName
                        onClicked: {
                            if (model.isDir)
                                folderModel.folder = model.url;
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
