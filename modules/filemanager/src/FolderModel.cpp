#include "FolderModel.h"

#include <KCoreDirLister>
#include <QDir>
#include <QStandardPaths>

FolderModel::FolderModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_lister(new KCoreDirLister(this))
{
    // Sin autoErrorHandling: una app QML no tiene el diálogo modal
    // QWidget que KCoreDirLister mostraría por defecto en error (carpeta
    // sin permisos, etc.) — errores se manejan en QML en un paso
    // posterior (fuera de scope del paso 2, que es solo "se ve el
    // listado real").
    m_lister->setAutoErrorHandlingEnabled(false);

    connect(m_lister, &KCoreDirLister::itemsAdded, this, &FolderModel::onItemsAdded);
    connect(m_lister, &KCoreDirLister::itemsDeleted, this, &FolderModel::onItemsDeleted);
    connect(m_lister, &KCoreDirLister::clear, this, &FolderModel::onClear);

    setFolder(QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::HomeLocation)));
}

QUrl FolderModel::folder() const
{
    return m_folder;
}

void FolderModel::setFolder(const QUrl &url)
{
    if (!url.isValid() || url == m_folder)
        return;

    m_folder = url;
    Q_EMIT folderChanged();
    // openUrl dispara onClear() + onItemsAdded() en cuanto KIO complete el
    // listado — no hace falta resetear el modelo a mano acá.
    m_lister->openUrl(url, KCoreDirLister::NoFlags);
}

int FolderModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.count();
}

QVariant FolderModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_items.count())
        return {};

    const KFileItem &item = m_items.at(index.row());

    switch (role) {
    case Qt::DisplayRole:
    case NameRole:
        return item.name();
    case IconNameRole:
        return item.iconName();
    case IsDirRole:
        return item.isDir();
    case UrlRole:
        return item.url();
    case SizeRole:
        return static_cast<qint64>(item.size());
    case MimeTypeRole:
        return item.mimetype();
    default:
        return {};
    }
}

QHash<int, QByteArray> FolderModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {IconNameRole, "iconName"},
        {IsDirRole, "isDir"},
        {UrlRole, "url"},
        {SizeRole, "size"},
        {MimeTypeRole, "mimeType"},
    };
}

void FolderModel::onItemsAdded(const QUrl &directoryUrl, const KFileItemList &items)
{
    if (directoryUrl != m_folder)
        return;

    beginInsertRows(QModelIndex(), m_items.count(), m_items.count() + items.count() - 1);
    m_items += items;
    endInsertRows();
}

void FolderModel::onItemsDeleted(const KFileItemList &items)
{
    for (const KFileItem &item : items) {
        const int row = m_items.indexOf(item);
        if (row < 0)
            continue;
        beginRemoveRows(QModelIndex(), row, row);
        m_items.removeAt(row);
        endRemoveRows();
    }
}

void FolderModel::onClear()
{
    beginResetModel();
    m_items.clear();
    endResetModel();
}
