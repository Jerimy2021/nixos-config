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

Q_SIGNALS:
    void operationSucceeded(const QString &operation);
    void operationFailed(const QString &operation, const QString &message);

private:
    void run(const QString &opName, const QStringList &args);
};
