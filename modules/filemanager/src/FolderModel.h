// Hito 005 — Fase 2, paso 2: modelo de listado de UNA carpeta a la vez,
// respaldado por KCoreDirLister (KIOCore — sin QtWidgets, a diferencia de
// KDirLister/KIOWidgets, que no necesitamos). Expuesto a QML vía
// qmlRegisterType (ver main.cpp) — no existe un `import org.kde.kio` con
// modelos QML de fábrica, ver NIXOS_FILEMANAGER_HITO05_PLAN.md §1.5.
#pragma once

#include <KFileItem>
#include <QAbstractListModel>
#include <QUrl>

class KCoreDirLister;

class FolderModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QUrl folder READ folder WRITE setFolder NOTIFY folderChanged)
    // Follow-up (breadcrumb real, ver docs §11): la barra de ruta en QML
    // necesita saber dónde termina "Home" para poder mostrar el primer
    // segmento como "Home" en vez de listar /home/<user> a mano — CONSTANT
    // porque QStandardPaths::HomeLocation no cambia en la vida del
    // proceso, no hace falta NOTIFY.
    Q_PROPERTY(QUrl homeUrl READ homeUrl CONSTANT)
    // Feature 7 (toggle de ocultos, ver docs §11): KCoreDirLister YA
    // trae esto (showHiddenFiles/setShowHiddenFiles, oculto por default
    // — ver kcoredirlister.h) — se expone tal cual, no se reinventa
    // filtrado de dotfiles a mano sobre m_items.
    Q_PROPERTY(bool showHiddenFiles READ showHiddenFiles WRITE setShowHiddenFiles NOTIFY showHiddenFilesChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        IconNameRole,
        IsDirRole,
        UrlRole,
        SizeRole,
        MimeTypeRole,
    };
    Q_ENUM(Roles)

    explicit FolderModel(QObject *parent = nullptr);

    QUrl folder() const;
    void setFolder(const QUrl &url);
    QUrl homeUrl() const;
    bool showHiddenFiles() const;
    void setShowHiddenFiles(bool show);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

Q_SIGNALS:
    void folderChanged();
    void showHiddenFilesChanged();

private Q_SLOTS:
    void onItemsAdded(const QUrl &directoryUrl, const KFileItemList &items);
    void onItemsDeleted(const KFileItemList &items);
    void onClear();

private:
    KCoreDirLister *m_lister;
    KFileItemList m_items;
    QUrl m_folder;
};
