/*
 * Listening Tree — GitHub Releases support for the in-app updater.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */
#include "github.h"

#include <QCryptographicHash>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QSysInfo>

#include "lt_config.h"

#include "log.h"

namespace lt::updater {
static const QByteArray GITHUB_API_VERSION("2022-11-28");
static const QString API_HOST("api.github.com");
static constexpr int MAX_REDIRECTS = 8;

QString appVersion()
{
    return QStringLiteral(LT_APP_VERSION);
}

QString repository()
{
    return QStringLiteral(LT_GITHUB_REPO);
}

QString latestReleaseApiUrl()
{
    return QStringLiteral("https://api.github.com/repos/%1/releases/latest").arg(repository());
}

QString releaseListApiUrl()
{
    return QStringLiteral("https://api.github.com/repos/%1/releases?per_page=30").arg(repository());
}

QString releasesPageUrl()
{
    return QStringLiteral("https://github.com/%1/releases").arg(repository());
}

QString versionFromTag(const QString& tag)
{
    QString v = tag.trimmed();
    if (v.startsWith(u'v') || v.startsWith(u'V')) {
        v.remove(0, 1);
    }
    return v;
}

static QString userAgent()
{
    return QStringLiteral(LT_SETTINGS_NAME "/" LT_APP_VERSION " (macOS; %1)").arg(QSysInfo::buildCpuArchitecture());
}

static QString keychainToken()
{
#if defined(Q_OS_MACOS) && defined(QT_QPROCESS_SUPPORTED)
    // /usr/bin/security created the item (scripts/set-update-token.sh), so it can
    // read it back without a Keychain prompt, and the item survives app updates.
    QProcess security;
    security.start(QStringLiteral("/usr/bin/security"), {
        QStringLiteral("find-generic-password"),
        QStringLiteral("-s"), QStringLiteral(LT_UPDATE_TOKEN_KEYCHAIN_SERVICE),
        QStringLiteral("-a"), QStringLiteral(LT_UPDATE_TOKEN_KEYCHAIN_ACCOUNT),
        QStringLiteral("-w"),
    });
    if (!security.waitForFinished(5000)) {
        security.kill();
        security.waitForFinished(1000);
        LOGW() << "Timed out reading the GitHub token from the Keychain";
        return QString();
    }
    if (security.exitStatus() != QProcess::NormalExit || security.exitCode() != 0) {
        return QString(); // no token stored: fine for public repositories
    }
    return QString::fromUtf8(security.readAllStandardOutput()).trimmed();
#else
    return QString();
#endif
}

QString token()
{
    const QString fromEnv = qEnvironmentVariable("LISTENING_TREE_GITHUB_TOKEN").trimmed();
    if (!fromEnv.isEmpty()) {
        return fromEnv;
    }
    return keychainToken();
}

muse::network::RequestHeaders apiHeaders(const muse::network::RequestHeaders& base)
{
    muse::network::RequestHeaders headers = base;
    headers.knownHeaders[QNetworkRequest::UserAgentHeader] = userAgent();
    headers.rawHeaders["Accept"] = "application/vnd.github+json";
    headers.rawHeaders["X-GitHub-Api-Version"] = GITHUB_API_VERSION;

    const QString t = token();
    if (!t.isEmpty()) {
        headers.rawHeaders["Authorization"] = "Bearer " + t.toUtf8();
    }
    return headers;
}

std::optional<Asset> pickMacAsset(const QJsonArray& assets)
{
    const QString arch = QSysInfo::buildCpuArchitecture(); // the CPU this build runs as: "arm64" or "x86_64"
    const bool isArm = arch.startsWith(QStringLiteral("arm"));

    auto score = [isArm](const QString& fileName) {
        const QString n = fileName.toLower();
        if (!n.endsWith(QStringLiteral(".dmg"))) {
            return -1;
        }
        const bool armBuild = n.contains(QStringLiteral("arm64")) || n.contains(QStringLiteral("aarch64"))
                              || n.contains(QStringLiteral("apple-silicon"));
        const bool intelBuild = n.contains(QStringLiteral("x86_64")) || n.contains(QStringLiteral("x64"))
                                || n.contains(QStringLiteral("intel"));
        if ((isArm && armBuild) || (!isArm && intelBuild)) {
            return 3;
        }
        if (n.contains(QStringLiteral("universal"))) {
            return 2;
        }
        if (armBuild || intelBuild) {
            return -1; // built for the other kind of Mac
        }
        return 1;
    };

    std::optional<Asset> best;
    int bestScore = 0;
    for (const QJsonValue& value : assets) {
        const QJsonObject obj = value.toObject();
        const QString name = obj.value(QStringLiteral("name")).toString();
        const int s = score(name);
        if (s <= bestScore) {
            continue;
        }

        Asset asset;
        asset.name = name;
        asset.downloadUrl = obj.value(QStringLiteral("browser_download_url")).toString();
        asset.apiUrl = obj.value(QStringLiteral("url")).toString();
        asset.size = static_cast<qint64>(obj.value(QStringLiteral("size")).toDouble());

        const QString digest = obj.value(QStringLiteral("digest")).toString();
        if (digest.startsWith(QStringLiteral("sha256:"))) {
            asset.sha256 = digest.mid(7).toLower();
        }

        best = asset;
        bestScore = s;
    }
    return best;
}

std::vector<ReleaseNotes> parseReleaseList(const QByteArray& json, bool includePrereleases)
{
    std::vector<ReleaseNotes> result;

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray()) {
        LOGE() << "Could not parse the release list: " << err.errorString();
        return result;
    }

    for (const QJsonValue& value : doc.array()) {
        const QJsonObject release = value.toObject();
        if (release.value(QStringLiteral("draft")).toBool()) {
            continue;
        }
        if (release.value(QStringLiteral("prerelease")).toBool() && !includePrereleases) {
            continue;
        }
        const QString version = versionFromTag(release.value(QStringLiteral("tag_name")).toString());
        if (version.isEmpty()) {
            continue;
        }
        result.push_back({ version.toStdString(), release.value(QStringLiteral("body")).toString().toStdString() });
    }
    return result;
}

QString sha256OfFile(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    QCryptographicHash hash(QCryptographicHash::Sha256);
    if (!hash.addData(&file)) {
        return QString();
    }
    return QString::fromLatin1(hash.result().toHex());
}

// ---------------------------------------------------------------------------
// AssetDownloader
// ---------------------------------------------------------------------------

AssetDownloader::AssetDownloader()
    : m_manager(std::make_unique<QNetworkAccessManager>())
{
}

AssetDownloader::~AssetDownloader()
{
    m_finished = true;
    if (m_reply) {
        m_reply->abort();
    }
    if (m_file.isOpen()) {
        m_file.close();
    }
}

void AssetDownloader::start(const Asset& asset, const QString& destinationPath, ProgressCallback onProgress, DoneCallback onDone)
{
    m_onProgress = std::move(onProgress);
    m_onDone = std::move(onDone);
    m_expectedSize = asset.size;
    m_finished = false;

    m_file.setFileName(destinationPath);
    if (!m_file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        finish(false, QStringLiteral("Cannot write %1: %2").arg(destinationPath, m_file.errorString()));
        return;
    }

    // With a token (private repository) go through the API; otherwise use the public download link.
    const bool useApi = !token().isEmpty() && !asset.apiUrl.isEmpty();
    const QUrl url(useApi ? asset.apiUrl : asset.downloadUrl);
    if (!url.isValid() || url.scheme() != QStringLiteral("https")) {
        finish(false, QStringLiteral("The release has no usable download link for %1").arg(asset.name));
        return;
    }

    LOGI() << "Downloading update " << asset.name << " from " << url.host() << (useApi ? " (with token)" : "");
    request(url, useApi, MAX_REDIRECTS);
}

void AssetDownloader::cancel()
{
    if (m_finished) {
        return;
    }
    m_finished = true;
    if (m_reply) {
        m_reply->abort();
    }
    m_file.close();
    m_file.remove();
}

void AssetDownloader::finish(bool ok, const QString& error)
{
    if (m_finished) {
        return;
    }
    m_finished = true;
    if (m_file.isOpen()) {
        m_file.close();
    }
    if (!ok) {
        m_file.remove();
        LOGE() << "Update download failed: " << error;
    }
    if (m_onDone) {
        m_onDone(ok, error);
    }
}

void AssetDownloader::request(const QUrl& url, bool withToken, int redirectsLeft)
{
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    req.setHeader(QNetworkRequest::UserAgentHeader, userAgent());
    if (withToken) {
        req.setRawHeader("Accept", "application/octet-stream");
        req.setRawHeader("X-GitHub-Api-Version", GITHUB_API_VERSION);
        req.setRawHeader("Authorization", "Bearer " + token().toUtf8());
    }

    QNetworkReply* reply = m_manager->get(req);
    m_reply = reply;

    auto httpStatus = [reply]() {
        return reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    };

    QObject::connect(reply, &QNetworkReply::readyRead, reply, [this, reply, httpStatus]() {
        if (m_finished) {
            return;
        }
        if (httpStatus() != 200) {
            reply->readAll(); // a redirect or error body, not the file
            return;
        }
        const QByteArray chunk = reply->readAll();
        if (m_file.write(chunk) != chunk.size()) {
            const QString error = QStringLiteral("Cannot write %1: %2").arg(m_file.fileName(), m_file.errorString());
            reply->abort();
            finish(false, error);
        }
    });

    QObject::connect(reply, &QNetworkReply::downloadProgress, reply, [this, httpStatus](qint64 received, qint64 total) {
        if (m_finished || httpStatus() != 200 || !m_onProgress) {
            return;
        }
        m_onProgress(received, total > 0 ? total : m_expectedSize);
    });

    QObject::connect(reply, &QNetworkReply::finished, reply, [this, reply, withToken, redirectsLeft, httpStatus]() {
        reply->deleteLater();
        if (m_finished) {
            return;
        }

        const int status = httpStatus();
        if (status >= 300 && status < 400) {
            QUrl target = reply->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
            if (!target.isValid()) {
                target = QUrl::fromEncoded(reply->rawHeader("Location"));
            }
            target = reply->url().resolved(target);
            if (redirectsLeft <= 0 || !target.isValid()) {
                finish(false, QStringLiteral("Too many redirects while downloading the update"));
                return;
            }
            if (target.scheme() != QStringLiteral("https")) {
                finish(false, QStringLiteral("Refusing to download the update over an insecure connection"));
                return;
            }
            // The token is only ever sent to the GitHub API, never to the storage server.
            request(target, withToken && target.host() == API_HOST, redirectsLeft - 1);
            return;
        }

        if (reply->error() != QNetworkReply::NoError || status != 200) {
            QString error = QStringLiteral("HTTP %1: %2").arg(status).arg(reply->errorString());
            if ((status == 404 || status == 401 || status == 403) && token().isEmpty()) {
                error += QStringLiteral(" (if the repository is private, see \"GitHub token\" in docs/UPDATING.md)");
            }
            finish(false, error);
            return;
        }

        const QByteArray rest = reply->readAll();
        if (!rest.isEmpty() && m_file.write(rest) != rest.size()) {
            finish(false, QStringLiteral("Cannot write %1: %2").arg(m_file.fileName(), m_file.errorString()));
            return;
        }
        m_file.close();

        const qint64 written = QFileInfo(m_file.fileName()).size();
        if (m_expectedSize > 0 && written != m_expectedSize) {
            finish(false, QStringLiteral("Downloaded %1 bytes, expected %2").arg(written).arg(m_expectedSize));
            return;
        }
        finish(true, QString());
    });
}
}
