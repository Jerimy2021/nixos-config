// Feature 8 (ver docs/NIXOS_ARCHITECTURE_HITO_005.md §11): filtro rápido
// tipo-para-filtrar, scopeado a la carpeta actual (nunca recursivo — solo
// filtra las filas que FolderModel ya listó, no dispara ningún listado
// nuevo). QSortFilterProxyModel es el primitivo REAL de Qt para exactamente
// esto — se subclasea solo para (a) agregar un `filterText` QString como
// Q_PROPERTY apto para bindear desde QML directo a un TextField.text, y (b)
// reemplazar el match por defecto (substring/regex exacto) por un fuzzy
// match de subsecuencia ("cada letra del patrón aparece en orden en el
// nombre, no necesariamente seguida") — el "fzf-style fast-filter feel"
// pedido explícitamente. roleNames()/data() del FolderModel real se
// heredan tal cual de QSortFilterProxyModel, así que ningún delegate de
// QML necesita tocarse (siguen leyendo model.name/model.isDir/etc, ahora a
// través del proxy en vez de directo).
#pragma once

#include <QSortFilterProxyModel>
#include <QString>

class FolderFilterProxy : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)

public:
    explicit FolderFilterProxy(QObject *parent = nullptr);

    QString filterText() const;
    void setFilterText(const QString &text);

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;

Q_SIGNALS:
    void filterTextChanged();

private:
    static bool fuzzyMatch(const QString &pattern, const QString &text);

    QString m_filterText;
};
