#include "FileOperations.h"

#include <KIO/OpenUrlJob>
#include <KJob>
#include <QProcess>
#include <memory>

FileOperations::FileOperations(QObject *parent)
    : QObject(parent)
{
}

void FileOperations::copyPath(const QUrl &src, const QUrl &dst)
{
    run(QStringLiteral("copy"), {QStringLiteral("copy"), src.toLocalFile(), dst.toLocalFile()});
}

void FileOperations::movePath(const QUrl &src, const QUrl &dst)
{
    run(QStringLiteral("move"), {QStringLiteral("move"), src.toLocalFile(), dst.toLocalFile()});
}

void FileOperations::makeDir(const QUrl &path)
{
    run(QStringLiteral("mkdir"), {QStringLiteral("mkdir"), path.toLocalFile()});
}

void FileOperations::removePermanently(const QUrl &path)
{
    run(QStringLiteral("delete"), {QStringLiteral("delete"), path.toLocalFile()});
}

void FileOperations::moveToTrash(const QUrl &path)
{
    run(QStringLiteral("trash"), {QStringLiteral("trash"), path.toLocalFile()});
}

void FileOperations::openFile(const QUrl &path)
{
    auto *job = new KIO::OpenUrlJob(path, this);
    connect(job, &KJob::result, this, [this, job]() {
        if (job->error()) {
            Q_EMIT operationFailed(QStringLiteral("open"), job->errorString());
        } else {
            Q_EMIT operationSucceeded(QStringLiteral("open"));
        }
    });
    job->start();
}

void FileOperations::run(const QString &opName, const QStringList &args)
{
    // nixfm-fileops se busca por PATH (igual que WorkspaceSync.qml llama
    // "workspace-wallpaper" por nombre, no por ruta de store) — se instala
    // junto con nixfm en home.packages (ver home.nix), así que está
    // garantizado presente en el PATH real del usuario.
    auto *proc = new QProcess(this);
    proc->setProgram(QStringLiteral("nixfm-fileops"));
    proc->setArguments(args);

    // Un solo reporte por proceso — QProcess puede disparar tanto
    // errorOccurred (p.ej. FailedToStart, si nixfm-fileops no estuviera en
    // PATH) como finished (con status Crashed) para el mismo fallo en
    // ciertos casos; sin esta guarda, la UI vería el mismo error dos veces.
    auto reported = std::make_shared<bool>(false);

    connect(proc, &QProcess::finished, this, [this, proc, opName, reported](int exitCode, QProcess::ExitStatus status) {
        if (!*reported) {
            *reported = true;
            if (status == QProcess::NormalExit && exitCode == 0) {
                Q_EMIT operationSucceeded(opName);
            } else {
                QString err = QString::fromUtf8(proc->readAllStandardError()).trimmed();
                if (err.isEmpty()) {
                    err = QStringLiteral("salió con código %1").arg(exitCode);
                }
                Q_EMIT operationFailed(opName, err);
            }
        }
        proc->deleteLater();
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc, opName, reported](QProcess::ProcessError) {
        if (!*reported) {
            *reported = true;
            Q_EMIT operationFailed(opName, proc->errorString());
        }
    });

    proc->start();
}
