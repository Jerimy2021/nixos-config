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

QUrl FolderModel::homeUrl() const
{
    return QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::HomeLocation));
}

bool FolderModel::showHiddenFiles() const
{
    return m_lister->showHiddenFiles();
}

void FolderModel::setShowHiddenFiles(bool show)
{
    if (m_lister->showHiddenFiles() == show)
        return;
    m_lister->setShowHiddenFiles(show);
    // setShowHiddenFiles() por sí sola no re-lista nada — emitChanges()
    // es lo que efectivamente aplica el filtro nuevo sobre la carpeta ya
    // abierta (documentado así en kcoredirlister.h). Sin esto el toggle
    // cambiaría el property pero el listado visible quedaría igual hasta
    // la próxima navegación real.
    m_lister->emitChanges();
    Q_EMIT showHiddenFilesChanged();
}

void FolderModel::setFolder(const QUrl &url)
{
    // Fix (ver docs/NIXOS_ARCHITECTURE_HITO_005.md §13 — bug real
    // reportado en vivo: "Subir"/breadcrumb dejaban el listado en blanco):
    // QML arma la URL de distintas formas según el camino de navegación —
    // KFileItem::url() (doble-click hacia adelante, Home inicial) nunca
    // trae "/" final, pero el botón "Subir" y los pills del breadcrumb
    // (Main.qml) SÍ le agregan "/" a mano al final. KCoreDirLister reporta
    // en onItemsAdded() la URL en SU forma canónica (sin esa barra final
    // agregada a mano), así que comparar contra m_folder guardado tal cual
    // llegó rompía el chequeo `directoryUrl != m_folder` de onItemsAdded()
    // más abajo — descartaba el listado entero en silencio, carpeta
    // vacía para siempre hasta la próxima navegación que sí calzara.
    // adjusted(StripTrailingSlash) normaliza acá, una sola vez, para que a
    // QML no le importe qué convención use cada botón.
    const QUrl normalized = url.adjusted(QUrl::StripTrailingSlash);
    if (!normalized.isValid() || normalized == m_folder)
        return;

    m_folder = normalized;
    Q_EMIT folderChanged();
    // openUrl dispara onClear() + onItemsAdded() en cuanto KIO complete el
    // listado — no hace falta resetear el modelo a mano acá.
    m_lister->openUrl(m_folder, KCoreDirLister::NoFlags);
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
    // Mismo fix que setFolder() (ver comentario ahí): m_folder ya llega
    // normalizado, pero directoryUrl es lo que KIO reporta tal cual — se
    // normaliza acá también en vez de asumir que coincide byte a byte con
    // la forma que adjusted(StripTrailingSlash) produce.
    if (directoryUrl.adjusted(QUrl::StripTrailingSlash) != m_folder)
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
