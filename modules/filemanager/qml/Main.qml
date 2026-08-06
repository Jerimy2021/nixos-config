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
