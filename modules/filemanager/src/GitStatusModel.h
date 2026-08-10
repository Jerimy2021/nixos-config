// Feature 4 (ver docs/NIXOS_ARCHITECTURE_HITO_005.md §11): decoraciones de
// git status para el listado. Mismo patrón que FileOperations — QProcess
// para un binario externo (acá "git" en vez de "nixfm-fileops"), porque
// nixfm no tiene ningún wrapper QML nativo para correr procesos.
//
// Diseño: DOS QProcess por navegación de carpeta, no uno por archivo — (1)
// `git rev-parse --show-toplevel` para saber si la carpeta está dentro de
// un repo Y encontrar la raíz real (m_repoRoot, sí se usa el stdout esta
// vez, ver fix de abajo), (2) si es un repo, `git status --porcelain
// --ignored .` corrido CON `-C <carpeta>`. El resultado se guarda en un
// solo QVariantMap (nombre del primer componente del path -> categoría)
// expuesto como Q_PROPERTY con NOTIFY — QML lee
// gitStatus.statusMap[model.name] por fila, un lookup de mapa, no un
// proceso por fila ni por repintado.
//
// Fix real (bug reportado por el usuario, ver docs §12: "git status no
// aparece navegando a una SUBCARPETA de un repo real"): la primera
// versión asumía que `-C <carpeta> status --porcelain ... .` entregaba
// paths relativos a <carpeta> — FALSO, confirmado en vivo comparando
// `git -C subcarpeta status --porcelain .` contra `cd subcarpeta &&
// git status --porcelain .`: los dos dan el path relativo a la RAÍZ del
// repo, siempre, sin importar `-C` ni el pathspec — es el formato
// porcelain el que fuerza esto (para que el output sea estable/parseable
// sin importar desde dónde se invoque, a diferencia del `git status`
// humano, que sí es relativo al cwd). El detector de raíz (`git
// rev-parse --show-toplevel`) nunca fue el problema — YA camina hacia
// arriba correctamente, es de fábrica; el bug real estaba en la
// suposición sobre el FORMATO del path que devuelve status, no en la
// detección de la raíz. Fix: `m_repoRoot` (nuevo, guardado del stdout
// del primer proceso) + recortar cada path porcelain contra "carpeta
// browseada, relativa a m_repoRoot" antes de tomar el primer componente
// — ver GitStatusModel.cpp.
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
    // Raíz real del repo (path local, sin file://), capturada del
    // stdout de `rev-parse --show-toplevel` — ver fix arriba.
    QString m_repoRoot;
};
