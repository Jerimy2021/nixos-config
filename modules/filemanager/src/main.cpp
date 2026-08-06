// Hito 005 — Fase 2. Paso 1: arranca el motor QML y carga Main.qml. Paso 2
// (ver NIXOS_FILEMANAGER_HITO05_PLAN.md §8): registra los dos puentes C++
// que KIO no expone a QML de fábrica — FolderModel (KCoreDirLister propio,
// ver FolderModel.h) y KFilePlacesModel (ya es un QAbstractItemModel de
// KIO, no hace falta envolverlo, solo registrarlo como tipo QML
// instanciable).
#include "FolderModel.h"

#include <KFilePlacesModel>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nixfm"));
    app.setOrganizationName(QStringLiteral("nixos"));
    app.setOrganizationDomain(QStringLiteral("nixos.local"));

    qmlRegisterType<FolderModel>("org.nixos.filemanager", 1, 0, "FolderModel");
    qmlRegisterType<KFilePlacesModel>("org.nixos.filemanager", 1, 0, "PlacesModel");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("org.nixos.filemanager", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
