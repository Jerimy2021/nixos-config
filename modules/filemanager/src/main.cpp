// Hito 005 — Fase 2. Paso 1: arranca el motor QML y carga Main.qml. Paso 2
// (ver NIXOS_FILEMANAGER_HITO05_PLAN.md §8): registra los dos puentes C++
// que KIO no expone a QML de fábrica — FolderModel (KCoreDirLister propio,
// ver FolderModel.h) y KFilePlacesModel (ya es un QAbstractItemModel de
// KIO, no hace falta envolverlo, solo registrarlo como tipo QML
// instanciable).
#include "FileOperations.h"
#include "FolderModel.h"
#include "GitStatusModel.h"
#include "PaletteWatcher.h"

#include <KFilePlacesModel>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nixfm"));
    app.setOrganizationName(QStringLiteral("nixos"));
    app.setOrganizationDomain(QStringLiteral("nixos.local"));

    // Bug real encontrado en vivo (ver NIXOS_ARCHITECTURE_HITO_005.md): sin
    // esto, QQC2 cae al style "Basic" de Qt (fondo blanco plano, checkboxes
    // genéricos, cero color de acento) — qqc2-desktop-style (ahora en
    // filemanager.nix) trae el plugin "org.kde.desktop" pero nada lo pedía
    // en tiempo de ejecución. QQuickStyle::setStyle() tiene la prioridad
    // MÁS ALTA de las cuatro formas que Qt documenta de elegir style
    // (por encima de -style, QT_QUICK_CONTROLS_STYLE y
    // qtquickcontrols2.conf) — no se puede pisar por variables de entorno
    // heredadas del contexto de lanzamiento (terminal/.desktop/keybind),
    // que es justo la robustez que hacía falta acá. Tiene que llamarse
    // ANTES de instanciar QQmlApplicationEngine.
    QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));

    qmlRegisterType<FolderModel>("org.nixos.filemanager", 1, 0, "FolderModel");
    qmlRegisterType<KFilePlacesModel>("org.nixos.filemanager", 1, 0, "PlacesModel");
    qmlRegisterType<PaletteWatcher>("org.nixos.filemanager", 1, 0, "PaletteWatcher");
    qmlRegisterType<FileOperations>("org.nixos.filemanager", 1, 0, "FileOperations");
    qmlRegisterType<GitStatusModel>("org.nixos.filemanager", 1, 0, "GitStatusModel");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("org.nixos.filemanager", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
