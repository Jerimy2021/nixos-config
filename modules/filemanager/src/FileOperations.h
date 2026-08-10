// Hito 005 — Fase 2, paso 4: copiar/mover/renombrar/crear carpeta/eliminar/
// papelera, vía el paquete `nixfm-fileops` (writeShellScriptBin, ver
// scripts.nix) corrido con QProcess — mismo patrón de "script empaquetado +
// proceso hijo" que hdmi-control/workspace-wallpaper ya usan en QuickShell,
// adaptado a QProcess porque nixfm no tiene el Quickshell.Io.Process de
// QuickShell disponible (ver plan §5.1: kioclient no existe en este
// nixpkgs, así que esto reemplaza esa idea original).
#pragma once

#include <QObject>
#include <QUrl>

class FileOperations : public QObject
{
    Q_OBJECT

public:
    explicit FileOperations(QObject *parent = nullptr);

    Q_INVOKABLE void copyPath(const QUrl &src, const QUrl &dst);
    Q_INVOKABLE void movePath(const QUrl &src, const QUrl &dst);
    Q_INVOKABLE void makeDir(const QUrl &path);
    Q_INVOKABLE void removePermanently(const QUrl &path);
    Q_INVOKABLE void moveToTrash(const QUrl &path);

    // Paso 5 (ver NIXOS_FILEMANAGER_HITO05_PLAN.md §5.1): abrir con la
    // misma xdg.mimeApps que ya declara home.nix — KIO::OpenUrlJob resuelve
    // el mimetype y lanza la app default real (lee el mismo
    // ~/.config/mimeapps.list que home-manager ya escribe), no una tabla
    // de asociaciones paralela.
    Q_INVOKABLE void openFile(const QUrl &path);

    // Feature 5 (ver docs/NIXOS_ARCHITECTURE_HITO_005.md §11): copiar la
    // ruta de la selección al portapapeles vía wl-copy (el mismo binario
    // que ya usan PRINT y Súper+V en keybinds.lua — ver comentario grande
    // en el .cpp) — no QGuiApplication::clipboard() ni ningún API Qt de
    // clipboard, mismo criterio de "reusar la herramienta externa ya
    // establecida" que FileOperations::run() con nixfm-fileops y
    // GitStatusModel con git.
    Q_INVOKABLE void copyAbsolutePath(const QUrl &path);
    // Relativa a la raíz del repo git más cercana — si `path` no está
    // adentro de un repo, cae de vuelta a la ruta absoluta (mismo
    // resultado que copyAbsolutePath en ese caso, no un error).
    Q_INVOKABLE void copyRelativePath(const QUrl &path);

Q_SIGNALS:
    void operationSucceeded(const QString &operation);
    void operationFailed(const QString &operation, const QString &message);

private:
    void run(const QString &opName, const QStringList &args);
    void copyTextToClipboard(const QString &text, const QString &opName);
};
