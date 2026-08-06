// Hito 005 — Fase 2, paso 1: scaffold desnudo. Solo arranca el motor QML y
// carga Main.qml — nada de KIO/modelos/temas todavía (ver
// NIXOS_FILEMANAGER_HITO05_PLAN.md §8, pasos numerados de la sesión).
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nixfm"));
    app.setOrganizationName(QStringLiteral("nixos"));
    app.setOrganizationDomain(QStringLiteral("nixos.local"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("org.nixos.filemanager", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
