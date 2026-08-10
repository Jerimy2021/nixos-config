#include "FolderFilterProxy.h"

FolderFilterProxy::FolderFilterProxy(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    // dynamicSortFilter ya viene true por default en QSortFilterProxyModel,
    // pero explícito acá porque es justo lo que hace que setFilterText()
    // re-evalúe filterAcceptsRow() sobre las filas ya listadas en vivo,
    // sin volver a pedirle nada a KCoreDirLister — el filtro es puramente
    // sobre lo que FolderModel YA tiene en memoria.
    setDynamicSortFilter(true);
}

QString FolderFilterProxy::filterText() const
{
    return m_filterText;
}

void FolderFilterProxy::setFilterText(const QString &text)
{
    if (m_filterText == text)
        return;
    m_filterText = text;
    Q_EMIT filterTextChanged();
    invalidateRowsFilter();
}

bool FolderFilterProxy::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    if (m_filterText.isEmpty() || !sourceModel())
        return true;

    const QModelIndex idx = sourceModel()->index(sourceRow, 0, sourceParent);
    // Qt::DisplayRole en vez del NameRole específico de FolderModel — el
    // data() de FolderModel ya devuelve item.name() para los dos roles
    // (ver FolderModel.cpp), así este proxy no necesita conocer el enum
    // Roles de un modelo en particular.
    const QString name = sourceModel()->data(idx, Qt::DisplayRole).toString();
    return fuzzyMatch(m_filterText, name);
}

bool FolderFilterProxy::fuzzyMatch(const QString &pattern, const QString &text)
{
    // Subsecuencia, no substring: "fzf-style" real es un scoring bastante
    // más elaborado (posición, contigüidad, límites de palabra); esto es
    // la versión liviana que igual da la sensación de "escribís letras
    // salteadas y el nombre aparece" sin traer una librería aparte para
    // una lista de una sola carpeta (unos pocos cientos de filas como
    // mucho, no hace falta un algoritmo con scoring para que se sienta
    // rápido).
    int ti = 0;
    const QString p = pattern.toCaseFolded();
    const QString t = text.toCaseFolded();
    for (const QChar &pc : p) {
        const int found = t.indexOf(pc, ti);
        if (found < 0)
            return false;
        ti = found + 1;
    }
    return true;
}
