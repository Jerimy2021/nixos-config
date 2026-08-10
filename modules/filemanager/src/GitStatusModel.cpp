#include "GitStatusModel.h"

#include <QDir>
#include <QProcess>

GitStatusModel::GitStatusModel(QObject *parent)
    : QObject(parent)
{
}

QUrl GitStatusModel::folder() const
{
    return m_folder;
}

bool GitStatusModel::isRepo() const
{
    return m_isRepo;
}

QVariantMap GitStatusModel::statusMap() const
{
    return m_statusMap;
}

void GitStatusModel::setFolder(const QUrl &url)
{
    if (!url.isValid() || url == m_folder)
        return;

    m_folder = url;
    Q_EMIT folderChanged();

    // Descarta cualquier respuesta pendiente de una carpeta anterior —
    // ver comentario grande en el .h.
    ++m_generation;

    if (m_isRepo) {
        m_isRepo = false;
        Q_EMIT isRepoChanged();
    }
    if (!m_statusMap.isEmpty()) {
        m_statusMap.clear();
        Q_EMIT statusMapChanged();
    }

    startToplevelCheck(m_folder, m_generation);
}

void GitStatusModel::startToplevelCheck(const QUrl &folder, int generation)
{
    auto *proc = new QProcess(this);
    proc->setProgram(QStringLiteral("git"));
    proc->setArguments({QStringLiteral("-C"), folder.toLocalFile(), QStringLiteral("rev-parse"), QStringLiteral("--show-toplevel")});

    connect(proc, &QProcess::finished, this, [this, proc, folder, generation](int exitCode, QProcess::ExitStatus status) {
        proc->deleteLater();
        // Carpeta ya cambió de nuevo mientras este proceso corría —
        // tirar el resultado, no corresponde a la carpeta actual.
        if (generation != m_generation)
            return;
        if (status == QProcess::NormalExit && exitCode == 0) {
            m_repoRoot = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
            m_isRepo = true;
            Q_EMIT isRepoChanged();
            startStatusQuery(folder, generation);
        }
        // exitCode != 0: no es un repo git — m_isRepo/m_statusMap ya
        // quedaron en false/vacío por setFolder(), nada más que hacer.
    });
    connect(proc, &QProcess::errorOccurred, this, [proc](QProcess::ProcessError) {
        // git ausente del PATH u otro fallo de arranque — silencioso a
        // propósito (mismo criterio que el resto de la app: "fuera de un
        // repo git" y "git no disponible" se ven igual para el usuario,
        // ningún archivo lleva decoración, sin diálogo de error por algo
        // que es simplemente cosmético).
        proc->deleteLater();
    });

    proc->start();
}

void GitStatusModel::startStatusQuery(const QUrl &folder, int generation)
{
    auto *proc = new QProcess(this);
    proc->setProgram(QStringLiteral("git"));
    proc->setArguments({QStringLiteral("-C"), folder.toLocalFile(), QStringLiteral("status"), QStringLiteral("--porcelain"), QStringLiteral("--ignored"), QStringLiteral(".")});

    connect(proc, &QProcess::finished, this, [this, proc, folder, generation](int, QProcess::ExitStatus) {
        proc->deleteLater();
        if (generation != m_generation)
            return;

        const QString output = QString::fromUtf8(proc->readAllStandardOutput());
        QVariantMap result;

        // Fix (bug real, ver comentario grande en el .h): `git status
        // --porcelain` SIEMPRE entrega paths relativos a la RAÍZ del
        // repo, nunca a `-C <folder>` ni al pathspec — confirmado en
        // vivo. Acá se recorta ese prefijo a mano: `browsedRel` es la
        // carpeta que se está mostrando, relativa a m_repoRoot (vacío
        // si se está parado justo en la raíz).
        QString browsedRel = QDir(m_repoRoot).relativeFilePath(folder.toLocalFile());
        if (browsedRel == QStringLiteral("."))
            browsedRel.clear();
        else
            browsedRel += QLatin1Char('/');

        // Formato porcelain v1: "XY PATH" (o "XY PATH -> NEWPATH" para
        // renames — nos importa NEWPATH, es el que existe hoy en la
        // carpeta).
        const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &line : lines) {
            if (line.size() < 4)
                continue;
            const QChar x = line.at(0);
            const QChar y = line.at(1);
            QString path = line.mid(3);
            const int arrow = path.indexOf(QStringLiteral(" -> "));
            if (arrow >= 0)
                path = path.mid(arrow + 4);
            if (path.startsWith(QLatin1Char('"')) && path.endsWith(QLatin1Char('"')) && path.size() >= 2)
                path = path.mid(1, path.size() - 2);

            // path llega relativo a la RAÍZ del repo — recortar contra
            // browsedRel para dejarlo relativo a la carpeta que se está
            // mostrando. Un path que no empieza con browsedRel es un
            // cambio FUERA de esta carpeta (ej. en una carpeta hermana)
            // — el pathspec "." ya debería excluir la mayoría de esos,
            // pero por las dudas se descarta acá también, no corresponde
            // a ninguna fila visible.
            if (!browsedRel.isEmpty()) {
                if (!path.startsWith(browsedRel))
                    continue;
                path = path.mid(browsedRel.length());
            }
            if (path.isEmpty())
                continue;

            // Solo el primer componente — así un cambio adentro de una
            // subcarpeta decora la SUBCARPETA (única fila visible en el
            // listado actual), no un path que no existe como fila.
            const int slash = path.indexOf(QLatin1Char('/'));
            const QString key = slash >= 0 ? path.left(slash) : path;

            QString category;
            if (x == QLatin1Char('U') || y == QLatin1Char('U') || (x == QLatin1Char('A') && y == QLatin1Char('A')) || (x == QLatin1Char('D') && y == QLatin1Char('D'))) {
                category = QStringLiteral("conflict");
            } else if (x != QLatin1Char(' ') && x != QLatin1Char('?') && x != QLatin1Char('!')) {
                category = QStringLiteral("staged");
            } else if (y == QLatin1Char('M') || y == QLatin1Char('T') || y == QLatin1Char('D')) {
                category = QStringLiteral("modified");
            } else if (x == QLatin1Char('?') && y == QLatin1Char('?')) {
                category = QStringLiteral("untracked");
            } else if (x == QLatin1Char('!') && y == QLatin1Char('!')) {
                category = QStringLiteral("ignored");
            } else {
                category = QStringLiteral("modified");
            }

            // Prioridad si ya había una categoría para esta key (varios
            // archivos modificados adentro de la misma subcarpeta, etc.):
            // conflict > staged > modified > untracked > ignored.
            static const QStringList priority = {QStringLiteral("conflict"), QStringLiteral("staged"), QStringLiteral("modified"), QStringLiteral("untracked"), QStringLiteral("ignored")};
            const auto existing = result.constFind(key);
            if (existing == result.constEnd() || priority.indexOf(category) < priority.indexOf(existing->toString())) {
                result.insert(key, category);
            }
        }

        m_statusMap = result;
        Q_EMIT statusMapChanged();
    });
    connect(proc, &QProcess::errorOccurred, this, [proc](QProcess::ProcessError) {
        proc->deleteLater();
    });

    proc->start();
}
