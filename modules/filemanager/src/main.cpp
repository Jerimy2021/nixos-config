// Hito 005 — Fase 2. Paso 1: arranca el motor QML y carga Main.qml. Paso 2
// (ver NIXOS_FILEMANAGER_HITO05_PLAN.md §8): registra los dos puentes C++
// que KIO no expone a QML de fábrica — FolderModel (KCoreDirLister propio,
// ver FolderModel.h) y KFilePlacesModel (ya es un QAbstractItemModel de
// KIO, no hace falta envolverlo, solo registrarlo como tipo QML
// instanciable).
#include "FileOperations.h"
#include "FolderFilterProxy.h"
#include "FolderModel.h"
#include "GitStatusModel.h"
#include "PaletteWatcher.h"

#include <KFilePlacesModel>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickStyle>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nixfm"));
    app.setOrganizationName(QStringLiteral("nixos"));
    app.setOrganizationDomain(QStringLiteral("nixos.local"));

    // Hito 005 §6 (migración final: dolphin -> nixfm) — gap real
    // encontrado auditando quién más invocaba "dolphin" directo por
    // fuera de keybinds.lua/xdg.mimeApps: modules/quickshell/modules/
    // dashboard/Shortcuts.qml lo lanzaba como `["dolphin", ruta]` (un
    // QProcess crudo, no vía Exec=%u de un .desktop) para sus accesos
    // directos de carpeta — Dolphin soporta un path como argv[1] de
    // fábrica, nixfm NO tenía NINGÚN manejo de argv (confirmado: el
    // main() de antes ni siquiera miraba argc/argv más allá de
    // pasárselo a QGuiApplication). Sin esto, el retiro de Dolphin
    // habría roto ese widget del dashboard en silencio. QUrl::
    // fromUserInput() de un solo argumento maneja los dos formatos
    // reales que puede llegar acá — un path crudo (Shortcuts.qml de
    // QuickShell) o una URI file:// (Exec=nixfm %u del .desktop, ver
    // home.nix, si algún día algo más lo invoca así) — sin tener que
    // distinguir a mano cuál de los dos es. Se expone a QML como
    // context property (no una env var — este proceso ya tiene
    // QQmlApplicationEngine, es la vía real para pasarle un dato de
    // arranque, ver el Component.onCompleted en Main.qml).
    QUrl startupFolder;
    if (app.arguments().size() > 1)
        startupFolder = QUrl::fromUserInput(app.arguments().at(1));

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
    qmlRegisterType<FolderFilterProxy>("org.nixos.filemanager", 1, 0, "FolderFilterProxy");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("startupFolderArg", startupFolder);
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("org.nixos.filemanager", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
