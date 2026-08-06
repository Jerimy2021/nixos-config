// Hito 005 — Fase 2. Paso 2: navegación real + sidebar de Places (ver
// NIXOS_FILEMANAGER_HITO05_PLAN.md §8). PageRow/animación de navegación
// llegan en el paso 5 — acá solo se verifica que el listado y el sidebar
// reflejan datos reales.
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

    PaletteWatcher {
        id: paletteWatcher
    }

    FolderModel {
        id: folderModel
    }

    PlacesModel {
        id: placesModel
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
                        icon.source: model.decoration
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
                        width: folderView.width
                        text: model.name
                        icon.name: model.iconName
                        onClicked: {
                            if (model.isDir)
                                folderModel.folder = model.url;
                        }
                    }
                }
            }
        }
    }
}
