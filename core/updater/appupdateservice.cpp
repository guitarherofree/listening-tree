/*
 * Listening Tree — app update service backed by GitHub Releases.
 *
 * This file replaces muse/framework/update/internal/appupdateservice.cpp in the
 * build (see patches/muse/0001-*). It implements the same class, declared in the
 * unchanged upstream header, but talks to the GitHub REST API instead of
 * MuseScore's/Audacity's update servers:
 *
 *   check     GET /repos/<owner>/<name>/releases/latest
 *             -> version from the tag, release notes from the release text,
 *                the .dmg that suits this Mac, its SHA-256 digest
 *   notes     GET /repos/<owner>/<name>/releases  (notes of versions you skipped)
 *   download  the .dmg, streamed to <user app data>/update/, checked against the digest
 *
 * Everything else (the dialogs, "Skip this version", "Remind me later", the
 * download progress window, the daily automatic check) is upstream code.
 * After the download, appshell's quit handler starts packaging/macos/install-update.sh
 * (see core/updater/installlauncher.cpp).
 *
 * Derived from MuseScore Studio's appupdateservice.cpp
 * (Copyright (C) 2025 MuseScore Limited and others).
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

#include "update/internal/appupdateservice.h"

#include <algorithm>
#include <map>

#include <QBuffer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QTimer>

#include "update/updateerrors.h"

#include "github.h"

#include "log.h"

using namespace muse;
using namespace muse::update;
using namespace muse::network;
using namespace muse::async;
using namespace muse::io;

namespace {
// One download at a time per service. Kept outside the class so the upstream header stays unchanged.
std::map<const AppUpdateService*, std::shared_ptr<lt::updater::AssetDownloader> > s_downloads;

Version currentVersion()
{
    return Version(lt::updater::appVersion().toStdString());
}

void releaseDownloadLater(const AppUpdateService* service)
{
    // Not synchronously: we may be inside a signal emitted by the downloader's network reply.
    QTimer::singleShot(0, [service]() { s_downloads.erase(service); });
}
}

void AppUpdateService::init()
{
    // Upstream records anonymous request statistics here for its own servers. Not needed for GitHub.
}

async::Promise<RetVal<ReleaseInfo> > AppUpdateService::checkForUpdate()
{
    return async::Promise<RetVal<ReleaseInfo> >([this](auto resolve, auto) {
        clear();

        if (configuration()->checkForUpdateTestMode()) {
            return resolve(m_lastCheckResult);
        }

        if (!m_networkManager) {
            m_networkManager = networkManagerCreator()->makeNetworkManager();
        }

        const QUrl url = QString::fromStdString(configuration()->checkForAppUpdateUrl());
        const RequestHeaders headers = lt::updater::apiHeaders(configuration()->updateHeaders());
        auto buff = std::make_shared<QBuffer>();

        LOGI() << "Checking for updates: " << url.toString();
        RetVal<Progress> progress = m_networkManager->get(url, buff, headers);
        if (!progress.ret) {
            m_lastCheckResult.ret = make_ret(Err::NetworkError, progress.ret.toString());
            return resolve(m_lastCheckResult);
        }

        progress.val.finished().onReceive(this, [this, buff, resolve](const ProgressResult& res) {
            if (!res.ret) {
                LOGE() << "Update check failed: " << res.ret.toString()
                       << (lt::updater::token().isEmpty()
                    ? " (if the GitHub repository is private, add a token: scripts/set-update-token.sh)" : "");
                m_lastCheckResult.ret = make_ret(Err::NetworkError, res.ret.toString());
                (void)resolve(m_lastCheckResult);
                return;
            }

            RetVal<ReleaseInfo> releaseInfo = parseRelease(buff->data());
            if (!releaseInfo.ret) {
                LOGE() << "Update check: " << releaseInfo.ret.toString();
                m_lastCheckResult.ret = releaseInfo.ret;
                (void)resolve(m_lastCheckResult);
                return;
            }

            const Version current = currentVersion();
            const Version update(releaseInfo.val.version);

            if (update.preRelease() && !configuration()->allowUpdateOnPreRelease()) {
                m_lastCheckResult.ret = make_ret(Err::NoUpdate);
                (void)resolve(m_lastCheckResult);
                return;
            }

            if (update <= current) {
                LOGI() << "Up to date: " << current.toStdString() << " (latest release " << update.toStdString() << ")";
                m_lastCheckResult.ret = make_ret(Err::NoUpdate);
                (void)resolve(m_lastCheckResult);
                return;
            }

            LOGI() << "Update available: " << current.toStdString() << " -> " << update.toStdString();
            m_lastCheckResult = releaseInfo;

            downloadPreviousReleasesNotes(update, [this, resolve](const PrevReleasesNotesList& notes) {
                m_lastCheckResult.val.previousReleasesNotes = notes;
                (void)resolve(m_lastCheckResult);
            });
        });

        return async::Promise<RetVal<ReleaseInfo> >::dummy_result();
    });
}

const RetVal<ReleaseInfo>& AppUpdateService::lastCheckResult() const
{
    return m_lastCheckResult;
}

RetVal<Progress> AppUpdateService::downloadRelease()
{
    const ReleaseInfo info = m_lastCheckResult.val;
    if (!info.isValid() || info.fileName.empty()) {
        return RetVal<Progress>::make_ret(make_ret(Err::UnknownError, "No update to download"));
    }

    lt::updater::Asset asset;
    asset.name = QString::fromStdString(info.fileName);
    asset.downloadUrl = QString::fromStdString(info.fileUrl);
    auto additional = [&info](const char* key) {
        auto it = info.additionInfo.find(key);
        return it == info.additionInfo.end() ? std::string() : it->second.toString();
    };
    asset.apiUrl = QString::fromStdString(additional("apiUrl"));
    asset.sha256 = QString::fromStdString(additional("sha256"));
    asset.size = QString::fromStdString(additional("size")).toLongLong();

    const path_t dir = configuration()->updateDataPath();
    fileSystem()->makePath(dir);
    const QString installerPath = (dir + "/" + info.fileName).toQString();

    auto downloader = std::make_shared<lt::updater::AssetDownloader>();
    s_downloads[this] = downloader;

    m_updateProgress = Progress();
    m_updateProgress.start();

    m_updateProgress.canceled().onNotify(this, [this, downloader]() {
        downloader->cancel();
        m_updateProgress.canceled().disconnect(this);
        releaseDownloadLater(this);
    });

    downloader->start(asset, installerPath,
                      [this](qint64 received, qint64 total) {
        m_updateProgress.progress(received, total);
    },
                      [this, installerPath, expectedSha = asset.sha256](bool ok, const QString& error) {
        m_updateProgress.canceled().disconnect(this);
        releaseDownloadLater(this);

        if (!ok) {
            m_updateProgress.finish(ProgressResult::make_ret(make_ret(Err::NetworkError, error.toStdString())));
            return;
        }

        if (!expectedSha.isEmpty()) {
            const QString actual = lt::updater::sha256OfFile(installerPath);
            if (actual != expectedSha) {
                LOGE() << "Update download is damaged: SHA-256 " << actual << ", expected " << expectedSha;
                QFile::remove(installerPath);
                m_updateProgress.finish(ProgressResult::make_ret(
                                            make_ret(Err::UnknownError, "The downloaded update failed its checksum test")));
                return;
            }
            LOGI() << "Update download verified (SHA-256 " << actual << ")";
        } else {
            LOGW() << "The release has no SHA-256 digest; the download was not checksum-verified";
        }

        m_updateProgress.finish(ProgressResult::make_ok(Val(installerPath.toStdString())));
    });

    return RetVal<Progress>::make_ok(m_updateProgress);
}

network::RequestHeaders AppUpdateService::prepareHeaders(const UpdateRequestHistory&) const
{
    return lt::updater::apiHeaders(configuration()->updateHeaders());
}

RetVal<AppUpdateService::UpdateRequestHistory> AppUpdateService::readUpdateRequestHistory(const io::path_t&) const
{
    return RetVal<UpdateRequestHistory>::make_ret(Ret::Code::NotSupported);
}

Ret AppUpdateService::writeUpdateRequestHistory(const io::path_t&, const UpdateRequestHistory&)
{
    return make_ret(Ret::Code::NotSupported);
}

RetVal<ReleaseInfo> AppUpdateService::parseRelease(const QByteArray& json) const
{
    QJsonParseError err;
    const QJsonDocument jsonDoc = QJsonDocument::fromJson(json, &err);
    if (err.error != QJsonParseError::NoError || !jsonDoc.isObject()) {
        return make_ret(Err::ReleaseInfoParseError, err.errorString().toStdString());
    }

    const QJsonObject release = jsonDoc.object();
    if (release.value("draft").toBool()) {
        return make_ret(Err::NoUpdate);
    }

    const QString version = lt::updater::versionFromTag(release.value("tag_name").toString());
    if (version.isEmpty() || Version(version.toStdString()).isNull()) {
        return make_ret(Err::ReleaseInfoParseError, "The latest release has no version tag (expected e.g. v1.2.3)");
    }

    const std::optional<lt::updater::Asset> asset = lt::updater::pickMacAsset(release.value("assets").toArray());
    if (!asset) {
        return make_ret(Err::ReleaseInfoParseError, "Release " + version.toStdString() + " has no macOS disk image (.dmg) for this Mac");
    }

    RetVal<ReleaseInfo> result;
    result.ret = muse::make_ok();
    result.val.version = version.toStdString();
    result.val.fileName = asset->name.toStdString();
    result.val.fileUrl = asset->downloadUrl.toStdString();
    result.val.notes = release.value("body").toString().toStdString();
    result.val.additionInfo["apiUrl"] = Val(asset->apiUrl.toStdString());
    result.val.additionInfo["sha256"] = Val(asset->sha256.toStdString());
    result.val.additionInfo["size"] = Val(QString::number(asset->size).toStdString());
    result.val.additionInfo["htmlUrl"] = Val(release.value("html_url").toString().toStdString());

    return result;
}

std::string AppUpdateService::platformFileSuffix() const
{
    return "dmg";
}

QJsonObject AppUpdateService::resolveReleaseAsset(const QJsonObject&) const
{
    return QJsonObject(); // replaced by lt::updater::pickMacAsset()
}

void AppUpdateService::downloadPreviousReleasesNotes(const Version& updateVersion, const PrevReleaseNotesCallback& finished)
{
    const QUrl url = QString::fromStdString(configuration()->previousAppReleasesNotesUrl());
    const RequestHeaders headers = lt::updater::apiHeaders(configuration()->updateHeaders());
    auto buff = std::make_shared<QBuffer>();

    RetVal<Progress> progress = m_networkManager->get(url, buff, headers);
    if (!progress.ret) {
        LOGE() << "Failed to get previous release notes: " << progress.ret.toString();
        finished({});
        return;
    }

    progress.val.finished().onReceive(this, [this, updateVersion, buff, finished](const ProgressResult& res) {
        PrevReleasesNotesList result;
        if (!res.ret) {
            LOGE() << "Failed to get previous release notes: " << res.ret.toString();
            finished(result);
            return;
        }

        const Version current = currentVersion();
        const bool includePrereleases = configuration()->allowUpdateOnPreRelease();
        for (const lt::updater::ReleaseNotes& r : lt::updater::parseReleaseList(buff->data(), includePrereleases)) {
            const Version v(r.version);
            // Notes of versions between the installed one and the update, which the user would otherwise miss.
            if (current < v && v < updateVersion) {
                result.emplace_back(r.version, r.notes);
            }
        }

        std::sort(result.begin(), result.end(), [](const PrevReleaseNotes& a, const PrevReleaseNotes& b) {
            return Version(a.version) < Version(b.version);
        });

        finished(result);
    });
}

void AppUpdateService::clear()
{
    m_lastCheckResult = RetVal<ReleaseInfo>::make_ok(ReleaseInfo());

#if !defined(Q_OS_LINUX)
    if (s_downloads.find(this) == s_downloads.end()) {
        fileSystem()->remove(configuration()->updateDataPath());
    }
#endif
}
