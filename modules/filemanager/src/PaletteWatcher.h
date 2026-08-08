// Hito 005 — Fase 2, paso 3: lee (y vigila) el acento resuelto que
// WorkspaceSync.qml (proceso de QuickShell, separado del nuestro) escribe
// en ~/.cache/quickshell/active-accent.json. Ver plan §3.2 — dos procesos
// QML distintos no comparten memoria, así que esto es el equivalente en
// C++ del FileView+watchChanges que usa WallpaperPalette.qml del lado de
// QuickShell, no una reinvención — mismo archivo compartido como
// mecanismo de IPC, ninguno nuevo.
//
// Follow-up post-Fase 2 (ver docs/NIXOS_ARCHITECTURE_HITO_005.md §8): un
// solo "accent" no alcanza para pisar el set completo de roles de
// Kirigami.Theme (background/texto/superficie son conceptos distintos del
// acento) — el archivo ahora carga 7 roles más, todos derivados por
// matugen en modo claro (par background/on_background con contraste
// garantizado, no HSL a mano — ver workspace-wallpaper en scripts.nix
// para el detalle de qué rol de Material mapea a cuál). Un solo
// paletteChanged() cubre las 8 propiedades — todas se actualizan juntas
// desde la misma lectura de archivo, no hace falta una señal por cada una.
#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QObject>

class PaletteWatcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QColor accent READ accent NOTIFY paletteChanged)
    Q_PROPERTY(QColor background READ background NOTIFY paletteChanged)
    Q_PROPERTY(QColor surfaceVariant READ surfaceVariant NOTIFY paletteChanged)
    Q_PROPERTY(QColor text READ text NOTIFY paletteChanged)
    Q_PROPERTY(QColor textMuted READ textMuted NOTIFY paletteChanged)
    Q_PROPERTY(QColor activeBackground READ activeBackground NOTIFY paletteChanged)
    Q_PROPERTY(QColor activeText READ activeText NOTIFY paletteChanged)
    Q_PROPERTY(QColor link READ link NOTIFY paletteChanged)

public:
    explicit PaletteWatcher(QObject *parent = nullptr);

    QColor accent() const { return m_accent; }
    QColor background() const { return m_background; }
    QColor surfaceVariant() const { return m_surfaceVariant; }
    QColor text() const { return m_text; }
    QColor textMuted() const { return m_textMuted; }
    QColor activeBackground() const { return m_activeBackground; }
    QColor activeText() const { return m_activeText; }
    QColor link() const { return m_link; }

Q_SIGNALS:
    void paletteChanged();

private:
    void reload();
    void ensureWatchingFile();

    QFileSystemWatcher m_watcher;
    QString m_path;

    // Defaults cream/terracotta/gold (ver mockup aprobado) — se usan en el
    // primer frame, antes de que exista el archivo, y como fallback
    // permanente para cualquier rol que el archivo todavía no incluya
    // (p. ej. primera vez que se ve un wallpaper, matugen corriendo en
    // background — mismo criterio de "nunca bloquear, degradar con
    // gracia" que ya usa el resto de este pipeline).
    QColor m_accent{QStringLiteral("#cba6f7")};
    QColor m_background{QStringLiteral("#faf3e8")};
    QColor m_surfaceVariant{QStringLiteral("#f2e6d3")};
    QColor m_text{QStringLiteral("#3d2b1f")};
    QColor m_textMuted{QStringLiteral("#7a6a5a")};
    QColor m_activeBackground{QStringLiteral("#f6dfc2")};
    QColor m_activeText{QStringLiteral("#2e1500")};
    QColor m_link{QStringLiteral("#8a6d1a")};
};
