/*
 * Listening Tree — GitHub Releases support for the in-app updater.
 *
 * Compiled into the MuseScore framework's update module (muse_update) by
 * patches/muse/0001-*. Used by core/updater/appupdateservice.cpp.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */
#pragma once

#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include <QByteArray>
#include <QFile>
#include <QJsonArray>
#include <QPointer>
#include <QString>
#include <QUrl>

#include "network/networktypes.h"

class QNetworkAccessManager;
class QNetworkReply;

namespace lt::updater {
//! Listening Tree's own version (from VERSION), e.g. "0.2.0".
QString appVersion();

//! "owner/name" of the GitHub repository that publishes releases.
QString repository();

//! REST endpoints and the human-facing releases page.
QString latestReleaseApiUrl();
QString releaseListApiUrl();
QString releasesPageUrl();

//! "v1.2.3" -> "1.2.3"
QString versionFromTag(const QString& tag);

//! A read-only GitHub token for private repositories, or an empty string.
//! Looked up in the LISTENING_TREE_GITHUB_TOKEN environment variable first,
//! then in the macOS Keychain (see scripts/set-update-token.sh).
QString token();

//! `base` plus the headers GitHub's REST API expects, and the token if there is one.
muse::network::RequestHeaders apiHeaders(const muse::network::RequestHeaders& base);

struct Asset {
    QString name;
    QString downloadUrl;   // browser_download_url: works without a token for public repositories
    QString apiUrl;        // REST url: used with the token for private repositories
    QString sha256;        // GitHub's "digest" for the file (lower-case hex), empty if not provided
    qint64 size = 0;
};

//! Picks the disk image that suits this Mac: one built for this CPU (arm64 or
//! x86_64), otherwise a universal one, otherwise a .dmg with no architecture in its name.
std::optional<Asset> pickMacAsset(const QJsonArray& assets);

struct ReleaseNotes {
    std::string version;
    std::string notes;
};

//! Parses the JSON from releaseListApiUrl(). Drafts are always skipped,
//! pre-releases unless `includePrereleases` is true.
std::vector<ReleaseNotes> parseReleaseList(const QByteArray& json, bool includePrereleases);

//! SHA-256 of a file as lower-case hex, or an empty string if it cannot be read.
QString sha256OfFile(const QString& path);

//! Streams a release asset to a file.
//!
//! For a private repository GitHub serves assets through the REST API, which
//! needs the token, and then redirects to a storage server. The token must not
//! be sent there (the server rejects it, and it would leak the token), so
//! redirects are followed by hand and the token is only sent to api.github.com.
class AssetDownloader
{
public:
    using ProgressCallback = std::function<void (qint64 received, qint64 total)>;
    using DoneCallback = std::function<void (bool ok, const QString& error)>;

    AssetDownloader();
    ~AssetDownloader();

    AssetDownloader(const AssetDownloader&) = delete;
    AssetDownloader& operator=(const AssetDownloader&) = delete;

    void start(const Asset& asset, const QString& destinationPath, ProgressCallback onProgress, DoneCallback onDone);

    //! Stops the download. The done callback is not called afterwards.
    void cancel();

private:
    void request(const QUrl& url, bool withToken, int redirectsLeft);
    void finish(bool ok, const QString& error);

    std::unique_ptr<QNetworkAccessManager> m_manager;
    QPointer<QNetworkReply> m_reply;
    QFile m_file;
    ProgressCallback m_onProgress;
    DoneCallback m_onDone;
    qint64 m_expectedSize = 0;
    bool m_finished = false;
};
}
