/*
 * Listening Tree — hands a downloaded update over to the installer script.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */
#include "installlauncher.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>

#include "log.h"

namespace lt::updater {
bool launchInstaller(const QString& dmgPath)
{
#if defined(Q_OS_MACOS) && defined(QT_QPROCESS_SUPPORTED)
    if (!dmgPath.endsWith(QStringLiteral(".dmg"), Qt::CaseInsensitive) || !QFileInfo::exists(dmgPath)) {
        LOGW() << "Not an update disk image: " << dmgPath;
        return false;
    }

    const QDir macosDir(QCoreApplication::applicationDirPath());   // <bundle>/Contents/MacOS
    const QString bundlePath = QDir::cleanPath(macosDir.absoluteFilePath(QStringLiteral("../..")));
    if (!bundlePath.endsWith(QStringLiteral(".app"))) {
        LOGW() << "Not running from an app bundle (" << bundlePath << "); install the update by hand";
        return false;
    }

    const QString bundledScript
        = QDir::cleanPath(macosDir.absoluteFilePath(QStringLiteral("../Resources/listening-tree/install-update.sh")));
    if (!QFileInfo::exists(bundledScript)) {
        LOGW() << "Update helper not found at " << bundledScript;
        return false;
    }

    // Run a copy: the original sits inside the bundle that is about to be replaced.
    const QString scriptCopy = QFileInfo(dmgPath).absolutePath() + QStringLiteral("/install-update.sh");
    QFile::remove(scriptCopy);
    if (!QFile::copy(bundledScript, scriptCopy)) {
        LOGW() << "Could not copy the update helper to " << scriptCopy;
        return false;
    }
    QFile::setPermissions(scriptCopy, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);

    const QStringList args = {
        scriptCopy,
        QStringLiteral("--dmg"), dmgPath,
        QStringLiteral("--target"), bundlePath,
        QStringLiteral("--wait-pid"), QString::number(QCoreApplication::applicationPid()),
        QStringLiteral("--settings-file"), QSettings().fileName(),
        QStringLiteral("--app-data"), QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation),
        QStringLiteral("--relaunch"),
    };

    qint64 pid = 0;
    if (!QProcess::startDetached(QStringLiteral("/bin/bash"), args, QString(), &pid)) {
        LOGW() << "Could not start the update helper";
        return false;
    }

    LOGI() << "Update helper started (pid " << pid << "); it will install " << dmgPath << " after the app quits";
    return true;
#else
    Q_UNUSED(dmgPath);
    return false;
#endif
}
}
