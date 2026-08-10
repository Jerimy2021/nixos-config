#include "FileOperations.h"

#include <KIO/OpenUrlJob>
#include <KJob>
#include <QDir>
#include <QFileInfo>
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

void FileOperations::copyAbsolutePath(const QUrl &path)
{
    copyTextToClipboard(path.toLocalFile(), QStringLiteral("copy-absolute-path"));
}

void FileOperations::copyRelativePath(const QUrl &path)
{
    const QString local = path.toLocalFile();
    const QFileInfo info(local);
    const QString searchDir = info.isDir() ? local : info.absolutePath();

    // Síncrono a propósito: es una acción de un solo click de menú
    // contextual, no algo en el camino de repintado (mismo criterio que
    // GitStatusModel, que SÍ es async porque corre en cada navegación de
    // carpeta) — `git rev-parse` local es casi instantáneo, y bloquear
    // brevemente acá es más simple que armar un flujo de señales para un
    // menú que ya se cerró apenas se hizo click.
    QProcess proc;
    proc.setProgram(QStringLiteral("git"));
    proc.setArguments({QStringLiteral("-C"), searchDir, QStringLiteral("rev-parse"), QStringLiteral("--show-toplevel")});
    proc.start();

    QString text = local; // fallback: ruta absoluta si no hay repo git
    if (proc.waitForFinished(2000) && proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0) {
        const QString root = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (!root.isEmpty()) {
            const QString rel = QDir(root).relativeFilePath(local);
            if (!rel.isEmpty())
                text = rel;
        }
    }
    copyTextToClipboard(text, QStringLiteral("copy-relative-path"));
}

void FileOperations::openTerminalHere(const QUrl &folder)
{
    auto *proc = new QProcess(this);
    proc->setProgram(QStringLiteral("foot"));
    proc->setArguments({QStringLiteral("-D"), folder.toLocalFile()});
    connect(proc, &QProcess::finished, proc, &QObject::deleteLater);
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError) {
        Q_EMIT operationFailed(QStringLiteral("open-terminal"), proc->errorString());
        proc->deleteLater();
    });
    proc->start();
    Q_EMIT operationSucceeded(QStringLiteral("open-terminal"));
}

void FileOperations::openSidepadHere(const QUrl &folder)
{
    // sidepad-toggle (ver scripts.nix — argumento $1 agregado esta
    // ronda) solo usa esta carpeta para ventanas NUEVAS; si el sidepad
    // claude/term ya existe, esto simplemente lo muestra/oculta como
    // siempre — una limitación real del script reusado, no de este
    // wrapper, documentada en docs §11 en vez de forzar un cd por fuera
    // (que requeriría inyectar texto en una shell ya corriendo, fuera de
    // alcance de esta ronda).
    auto *proc = new QProcess(this);
    proc->setProgram(QStringLiteral("sidepad-toggle"));
    proc->setArguments({folder.toLocalFile()});
    connect(proc, &QProcess::finished, proc, &QObject::deleteLater);
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError) {
        Q_EMIT operationFailed(QStringLiteral("open-sidepad"), proc->errorString());
        proc->deleteLater();
    });
    proc->start();
    Q_EMIT operationSucceeded(QStringLiteral("open-sidepad"));
}

void FileOperations::copyTextToClipboard(const QString &text, const QString &opName)
{
    // wl-copy (Súper+V y PRINT en keybinds.lua ya lo usan) lee el
    // contenido por stdin y se independiza (fork) para servir el
    // portapapeles — no hace falta esperar a que termine, solo escribirle
    // y cerrar el canal.
    auto *proc = new QProcess(this);
    proc->setProgram(QStringLiteral("wl-copy"));
    connect(proc, &QProcess::started, proc, [proc, text]() {
        proc->write(text.toUtf8());
        proc->closeWriteChannel();
    });
    connect(proc, &QProcess::finished, proc, &QObject::deleteLater);
    connect(proc, &QProcess::errorOccurred, this, [this, proc, opName](QProcess::ProcessError) {
        Q_EMIT operationFailed(opName, proc->errorString());
        proc->deleteLater();
    });
    proc->start();
    Q_EMIT operationSucceeded(opName);
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
