#include "PaletteWatcher.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

PaletteWatcher::PaletteWatcher(QObject *parent)
    : QObject(parent)
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

    const auto obj = QJsonDocument::fromJson(f.readAll()).object();
    if (obj.isEmpty()) {
        return;
    }

    // Cada rol cae a su default cream si la clave falta (wallpaper todavía
    // sin roles cacheados en filemanager-palette.json, ver
    // WorkspaceSync.qml) o si el hex es inválido — nunca deja el color
    // anterior a medias ni rompe con un color inválido.
    auto colorOr = [&obj](const char *key, const QColor &fallback) {
        const QColor c(obj.value(QLatin1String(key)).toString());
        return c.isValid() ? c : fallback;
    };

    const QColor accent = colorOr("hex", m_accent);
    const QColor background = colorOr("background", m_background);
    const QColor surfaceVariant = colorOr("surfaceVariant", m_surfaceVariant);
    const QColor text = colorOr("text", m_text);
    const QColor textMuted = colorOr("textMuted", m_textMuted);
    const QColor activeBackground = colorOr("activeBackground", m_activeBackground);
    const QColor activeText = colorOr("activeText", m_activeText);
    const QColor link = colorOr("link", m_link);

    if (accent == m_accent && background == m_background && surfaceVariant == m_surfaceVariant
        && text == m_text && textMuted == m_textMuted && activeBackground == m_activeBackground
        && activeText == m_activeText && link == m_link) {
        return;
    }

    m_accent = accent;
    m_background = background;
    m_surfaceVariant = surfaceVariant;
    m_text = text;
    m_textMuted = textMuted;
    m_activeBackground = activeBackground;
    m_activeText = activeText;
    m_link = link;
    Q_EMIT paletteChanged();
}
