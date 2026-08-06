#include "PaletteWatcher.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

PaletteWatcher::PaletteWatcher(QObject *parent)
    : QObject(parent)
    // Mismo lavender que Theme.qml usa como default antes de que matugen
    // resuelva algo — así el primer frame de nixfm no arranca con un color
    // random si todavía no hay cache (o si QuickShell nunca corrió).
    , m_accent(QStringLiteral("#cba6f7"))
{
    // GenericCacheLocation (no CacheLocation) a propósito: CacheLocation
    // le agrega el applicationName/organizationName propios de nixfm
    // (~/.cache/nixos/nixfm/...) — acá hace falta el directorio real y
    // COMPARTIDO que ya usa QuickShell (~/.cache/quickshell/), no uno
    // propio de esta app.
    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/quickshell");
    m_path = cacheDir + QStringLiteral("/active-accent.json");

    QDir().mkpath(cacheDir);
    m_watcher.addPath(cacheDir);
    ensureWatchingFile();

    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &) {
        ensureWatchingFile();
        reload();
    });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &) {
        reload();
        // Muchos escritores (acá: el Process de WorkspaceSync.qml, `printf
        // ... > archivo`) truncan+reescriben en vez de editar in-place —
        // QFileSystemWatcher a veces deja de vigilar la ruta después de
        // eso. Re-agregarla si sigue existiendo.
        ensureWatchingFile();
    });

    reload();
}

void PaletteWatcher::ensureWatchingFile()
{
    if (QFile::exists(m_path) && !m_watcher.files().contains(m_path)) {
        m_watcher.addPath(m_path);
    }
}

void PaletteWatcher::reload()
{
    QFile f(m_path);
    if (!f.open(QIODevice::ReadOnly)) {
        return;
    }

    const auto doc = QJsonDocument::fromJson(f.readAll());
    const QString hex = doc.object().value(QStringLiteral("hex")).toString();
    if (hex.isEmpty()) {
        return;
    }

    const QColor color(hex);
    if (!color.isValid() || color == m_accent) {
        return;
    }

    m_accent = color;
    Q_EMIT accentChanged();
}
