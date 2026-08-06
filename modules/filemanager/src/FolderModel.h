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

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

Q_SIGNALS:
    void folderChanged();

private Q_SLOTS:
    void onItemsAdded(const QUrl &directoryUrl, const KFileItemList &items);
    void onItemsDeleted(const KFileItemList &items);
    void onClear();

private:
    KCoreDirLister *m_lister;
    KFileItemList m_items;
    QUrl m_folder;
};
