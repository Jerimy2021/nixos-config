// Feature 4 (ver docs/NIXOS_ARCHITECTURE_HITO_005.md §11): decoraciones de
// git status para el listado. Mismo patrón que FileOperations — QProcess
// para un binario externo (acá "git" en vez de "nixfm-fileops"), porque
// nixfm no tiene ningún wrapper QML nativo para correr procesos.
//
// Diseño: DOS QProcess por navegación de carpeta, no uno por archivo — (1)
// `git rev-parse --show-toplevel` para saber si la carpeta está dentro de
// un repo (y encontrar la raíz, aunque acá solo se usa el código de salida:
// 0 = adentro de un repo, !=0 = no), (2) si es un repo, `git status
// --porcelain --ignored .` corrido CON `-C <carpeta>`, así los paths que
// devuelve ya vienen relativos a la carpeta que se está navegando, no a la
// raíz del repo — no hace falta recortar el prefijo a mano. El resultado
// se guarda en un solo QVariantMap (nombre del primer componente del path
// -> categoría) expuesto como Q_PROPERTY con NOTIFY — QML lee
// gitStatus.statusMap[model.name] por fila, un lookup de mapa, no un
// proceso por fila ni por repintado.
//
// "Debounce" real: no hay QTimer — folder se reasigna como mucho una vez
// por navegación real del usuario (clicks de breadcrumb/sidebar/listado no
// son eventos de alta frecuencia como un repintado), y un contador de
// generación descarta el resultado de cualquier QProcess que termine
// DESPUÉS de que folder ya cambió de nuevo (navegación rápida durante un
// git status todavía en vuelo) — sin eso, una respuesta vieja podría pisar
// el resultado de la carpeta nueva.
#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantMap>

class QProcess;

class GitStatusModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl folder READ folder WRITE setFolder NOTIFY folderChanged)
    Q_PROPERTY(bool isRepo READ isRepo NOTIFY isRepoChanged)
    Q_PROPERTY(QVariantMap statusMap READ statusMap NOTIFY statusMapChanged)

public:
    explicit GitStatusModel(QObject *parent = nullptr);

    QUrl folder() const;
    void setFolder(const QUrl &url);
    bool isRepo() const;
    QVariantMap statusMap() const;

Q_SIGNALS:
    void folderChanged();
    void isRepoChanged();
    void statusMapChanged();

private:
    void startToplevelCheck(const QUrl &folder, int generation);
    void startStatusQuery(const QUrl &folder, int generation);

    QUrl m_folder;
    bool m_isRepo = false;
    QVariantMap m_statusMap;
    int m_generation = 0;
};
