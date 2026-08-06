// Hito 005 — Fase 2, paso 3: lee (y vigila) el acento resuelto que
// WorkspaceSync.qml (proceso de QuickShell, separado del nuestro) escribe
// en ~/.cache/quickshell/active-accent.json. Ver plan §3.2 — dos procesos
// QML distintos no comparten memoria, así que esto es el equivalente en
// C++ del FileView+watchChanges que usa WallpaperPalette.qml del lado de
// QuickShell, no una reinvención — mismo archivo compartido como
// mecanismo de IPC, ninguno nuevo.
#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QObject>

class PaletteWatcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QColor accent READ accent NOTIFY accentChanged)

public:
    explicit PaletteWatcher(QObject *parent = nullptr);

    QColor accent() const { return m_accent; }

Q_SIGNALS:
    void accentChanged();

private:
    void reload();
    void ensureWatchingFile();

    QFileSystemWatcher m_watcher;
    QColor m_accent;
    QString m_path;
};
