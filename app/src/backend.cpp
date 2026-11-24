#include "backend.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QJsonDocument>
#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QClipboard>
#include <QDBusMetaType>
#include <QDBusVariant>
#include <QJSEngine>
#include <QDateTime>
#include <QDir>
#include <QGuiApplication>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QSystemTrayIcon>

// PINNA_BUS points the app at a test daemon
static const QString SERVICE = qEnvironmentVariable("PINNA_BUS", QStringLiteral("dev.pinna.Daemon"));
static const QString PATH = QStringLiteral("/dev/pinna/Daemon");
static bool inFlatpak() { return qEnvironmentVariableIsSet("FLATPAK_ID"); }
static const QString IFACE = QStringLiteral("dev.pinna.Daemon1");

static QString str(const QVariant &v)
{
    if (v.typeId() == QMetaType::Bool)
        return v.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    return v.toString();
}

Backend *Backend::instance()
{
    static Backend *b = new Backend(qApp);
    return b;
}

Backend *Backend::create(QQmlEngine *, QJSEngine *)
{
    auto *b = instance();
    QJSEngine::setObjectOwnership(b, QJSEngine::CppOwnership);
    return b;
}

Backend::Backend(QObject *parent) : QObject(parent)
{
    m_clock.start();
    m_trace = qEnvironmentVariableIsSet("PINNA_TRACE");
    // read from a file instead of the service, for screenshots and design work
    m_fake = qEnvironmentVariable("PINNA_STATE");
    if (!m_fake.isEmpty()) {
        QFile f(m_fake);
        if (f.open(QIODevice::ReadOnly))
            replaceState(QString::fromUtf8(f.readAll()));
        setDaemon(!m_state.isEmpty());
        return;
    }

    auto bus = QDBusConnection::sessionBus();
    bus.connect(SERVICE, PATH, IFACE, QStringLiteral("StateChanged"), this, SLOT(onState(QString)));
    bus.connect(SERVICE, PATH, IFACE, QStringLiteral("CaseOpened"), this, SLOT(onCase(QString)));
    qDBusRegisterMetaType<QList<qint16>>();
    bus.connect(SERVICE, PATH, IFACE, QStringLiteral("Head"), this, SLOT(onHead(QList<qint16>)));

    m_watcher = new QDBusServiceWatcher(SERVICE, bus,
        QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration, this);
    connect(m_watcher, &QDBusServiceWatcher::serviceRegistered, this, [this] { setDaemon(true); refresh(); });
    connect(m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, [this] {
        setDaemon(false);
        m_state.clear();
        emit stateChanged();
    });

    setDaemon(bus.interface()->isServiceRegistered(SERVICE));
    // a Flatpak has no systemd unit or D-Bus activation for the service, so it runs inside the sandbox
    if (!m_daemon && inFlatpak())
        QProcess::startDetached(QStringLiteral("pinnad"), {});
    refresh();
}

void Backend::setDaemon(bool up)
{
    if (m_daemon == up)
        return;
    m_daemon = up;
    emit daemonChanged();
}

void Backend::refresh()
{
    if (!m_fake.isEmpty())
        return;
    auto msg = QDBusMessage::createMethodCall(SERVICE, PATH, IFACE, QStringLiteral("State"));
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QString> r = *w;
        if (!r.isError()) {
            setDaemon(true);
            replaceState(r.value());
        }
        w->deleteLater();
    });
}

static QVariant getAt(const QVariantMap &m, const QString &group, const QString &key)
{
    return group.isEmpty() ? m.value(key) : m.value(group).toMap().value(key);
}

static void setAt(QVariantMap &m, const QString &group, const QString &key, const QVariant &v)
{
    if (group.isEmpty()) {
        m[key] = v;
        return;
    }
    auto g = m.value(group).toMap();
    g[key] = v;
    m[group] = g;
}

static bool same(const QVariant &a, const QVariant &b)
{
    if (a.typeId() == QMetaType::Bool || b.typeId() == QMetaType::Bool)
        return a.toBool() == b.toBool() && a.isValid() && b.isValid();
    return a.toString() == b.toString();
}

void Backend::optimistic(const QString &group, const QString &key, const QVariant &value)
{
    if (m_trace && key == QLatin1String("mode"))
        m_traceAt = m_clock.nsecsElapsed();
    setAt(m_state, group, key, value);
    m_pending.erase(std::remove_if(m_pending.begin(), m_pending.end(),
                                   [&](const Pending &p) { return p.group == group && p.key == key; }),
                    m_pending.end());
    m_pending.append({group, key, value, m_clock.elapsed()});
    emit stateChanged();
}

void Backend::frameShown()
{
    if (m_traceAt < 0)
        return;
    qInfo("pinna: click to frame %.2f ms", (m_clock.nsecsElapsed() - m_traceAt) / 1e6);
    m_traceAt = -1;
}

// the service only sends changed fields in the signal
void Backend::onState(const QString &json)
{
    auto next = m_state;
    const auto diff = QJsonDocument::fromJson(json.toUtf8()).toVariant().toMap();
    for (auto it = diff.begin(); it != diff.end(); ++it)
        next[it.key()] = it.value();
    apply(next);
}

void Backend::replaceState(const QString &json)
{
    apply(QJsonDocument::fromJson(json.toUtf8()).toVariant().toMap());
}

void Backend::apply(QVariantMap next)
{
    // keep the clicked value until the buds confirm, so a stale echo does not flip it back
    const qint64 now = m_clock.elapsed();
    for (auto it = m_pending.begin(); it != m_pending.end();) {
        if (now - it->at > 2500 || same(getAt(next, it->group, it->key), it->value)) {
            it = m_pending.erase(it);
        } else {
            setAt(next, it->group, it->key, it->value);
            ++it;
        }
    }
    m_state = next;
    emit stateChanged();
}

void Backend::onHead(const QList<qint16> &values)
{
    m_head.clear();
    for (auto v : values)
        m_head.append(int(v));
    emit headChanged();
}

void Backend::onCase(const QString &)
{
    emit caseOpened();
}

void Backend::call(const QString &method, const QVariantList &args)
{
    if (!m_fake.isEmpty()) {
        fakeCall(method, args);
        return;
    }
    auto msg = QDBusMessage::createMethodCall(SERVICE, PATH, IFACE, method);
    msg.setArguments(args);
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 30000), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<> r = *w;
        if (r.isError()) {
            m_pending.clear();
            // the service sends "code: message"; plain D-Bus errors mean it is unreachable
            const QString msg = r.error().message();
            const int colon = msg.indexOf(QLatin1String(": "));
            const bool coded = r.error().type() == QDBusError::Failed || r.error().type() == QDBusError::InvalidArgs;
            if (coded && colon > 0 && colon < 16)
                emit error(msg.left(colon), QCoreApplication::translate("Daemon", msg.mid(colon + 2).toUtf8().constData()));
            else
                emit error(QStringLiteral("service"), tr("Couldn't reach the Pinna service."));
            refresh();
        }
        w->deleteLater();
    });
}

void Backend::setMode(const QString &mode)
{
    optimistic({}, QStringLiteral("mode"), mode);
    call(QStringLiteral("SetMode"), {mode});
}

void Backend::setSetting(const QString &key, const QVariant &value)
{
    optimistic(QStringLiteral("settings"), key, value);
    call(QStringLiteral("SetSetting"), {key, str(value)});
}

void Backend::setPref(const QString &key, const QVariant &value)
{
    optimistic(QStringLiteral("prefs"), key, value);
    call(QStringLiteral("SetPref"), {key, str(value)});
}

void Backend::setAudio(const QString &key, const QVariant &value)
{
    if (key == QLatin1String("default"))
        optimistic(QStringLiteral("audio"), QStringLiteral("isDefault"), true);
    else
        optimistic(QStringLiteral("audio"), key, value);
    call(QStringLiteral("SetAudio"), {key, str(value)});
}

void Backend::rename(const QString &name)
{
    optimistic({}, QStringLiteral("name"), name);
    call(QStringLiteral("Rename"), {name});
}

void Backend::connectDevice() { call(QStringLiteral("Connect"), {}); }
void Backend::powerOn() { call(QStringLiteral("PowerOn"), {}); }
void Backend::disconnectDevice() { call(QStringLiteral("Disconnect"), {}); }
void Backend::select(const QString &address) { call(QStringLiteral("Select"), {address}); }
void Backend::forget(const QString &address) { call(QStringLiteral("Forget"), {address}); }
void Backend::discover(bool on) { call(QStringLiteral("Discover"), {on}); }
void Backend::pair(const QString &address) { call(QStringLiteral("Pair"), {address}); }

void Backend::headTracking(bool on)
{
    optimistic({}, QStringLiteral("headTracking"), on);
    if (!on) {
        m_head.clear();
        emit headChanged();
    }
    call(QStringLiteral("HeadTracking"), {on});
}

void Backend::loadHistory()
{
    if (!m_fake.isEmpty()) {
        // fixture history uses times of zero or below, seconds before now, so it never goes stale
        const qint64 now = QDateTime::currentSecsSinceEpoch();
        m_history.clear();
        for (const auto &row : m_state.value(QStringLiteral("history")).toList()) {
            auto r = row.toList();
            if (!r.isEmpty() && r[0].toLongLong() <= 0)
                r[0] = now + r[0].toLongLong();
            m_history << QVariant(r);
        }
        emit historyChanged();
        return;
    }
    auto msg = QDBusMessage::createMethodCall(SERVICE, PATH, IFACE, QStringLiteral("BatteryHistory"));
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QString> r = *w;
        if (!r.isError()) {
            m_history = QJsonDocument::fromJson(r.value().toUtf8()).toVariant().toList();
            emit historyChanged();
        }
        w->deleteLater();
    });
}

static QString autostartFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/autostart/dev.pinna.Pinna.desktop");
}

bool Backend::closeToTray() const { return QSettings().value(QStringLiteral("closeToTray"), true).toBool(); }

void Backend::setCloseToTray(bool on)
{
    QSettings().setValue(QStringLiteral("closeToTray"), on);
    emit appChanged();
}

// empty means the system language
QString Backend::language() const { return QSettings().value(QStringLiteral("language")).toString(); }

void Backend::setLanguage(const QString &lang)
{
    QSettings().setValue(QStringLiteral("language"), lang);
    emit languageChanged();
}

bool Backend::autostart() const
{
    if (inFlatpak())
        return QSettings().value(QStringLiteral("autostart"), false).toBool();
    return QFile::exists(autostartFile());
}

void Backend::setAutostart(bool on)
{
    if (inFlatpak()) {
        // the sandbox cannot write ~/.config/autostart, the portal does it for us
        QDBusMessage m = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.portal.Desktop"),
            QStringLiteral("/org/freedesktop/portal/desktop"), QStringLiteral("org.freedesktop.portal.Background"),
            QStringLiteral("RequestBackground"));
        QVariantMap opts{{QStringLiteral("autostart"), on},
                         {QStringLiteral("commandline"), QStringList{QStringLiteral("pinna"), QStringLiteral("--tray")}},
                         {QStringLiteral("reason"), tr("Show the AirPods battery in the tray after login")}};
        m.setArguments({QString(), opts});
        QDBusConnection::sessionBus().asyncCall(m);
        QSettings().setValue(QStringLiteral("autostart"), on);
    } else if (on) {
        QDir().mkpath(QFileInfo(autostartFile()).path());
        QFile f(autostartFile());
        if (f.open(QIODevice::WriteOnly)) {
            f.write(QStringLiteral("[Desktop Entry]\nType=Application\nName=Pinna\nExec=%1 --tray\nIcon=dev.pinna.Pinna\nX-GNOME-Autostart-enabled=true\n")
                        .arg(QCoreApplication::applicationFilePath())
                        .toUtf8());
        }
    } else {
        QFile::remove(autostartFile());
    }
    emit appChanged();
}

bool Backend::deviceIdOk() const
{
    QFile f(QStringLiteral("/etc/bluetooth/main.conf"));
    if (!f.open(QIODevice::ReadOnly))
        return false;
    for (const auto &l : f.readAll().split('\n')) {
        const auto t = l.trimmed();
        if (t.startsWith("DeviceID") && t.contains("bluetooth:004C"))
            return true;
    }
    return false;
}

// text shown to the user; the command that runs uses no shell
QString Backend::deviceIdCommand() const
{
    return QStringLiteral("pkexec sed -i '/^\\[General\\]/a DeviceID = bluetooth:004C:0000:0000' /etc/bluetooth/main.conf");
}

void Backend::setupDeviceId()
{
    if (deviceIdOk())
        return;
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p](int code) {
        p->deleteLater();
        if (code != 0) {
            // 126/127 from pkexec mean cancelled or not authorized
            emit error(QStringLiteral("deviceid"), code == 126 || code == 127 ? tr("The password prompt was closed; nothing changed.")
                                                                               : tr("Couldn't add the line (exit code %1).").arg(code));
            return;
        }
        emit appChanged();
        // BlueZ only reads the setting on restart; polkit asks for this itself
        auto *r = new QProcess(this);
        connect(r, &QProcess::finished, this, [this, r](int c) {
            r->deleteLater();
            emit notice(c == 0 ? tr("DeviceID added, Bluetooth restarted.")
                               : tr("DeviceID added. Restart Bluetooth for it to take effect."));
        });
        r->start(QStringLiteral("systemctl"), {QStringLiteral("restart"), QStringLiteral("bluetooth.service")});
    });
    p->start(QStringLiteral("pkexec"), {QStringLiteral("/usr/bin/sed"), QStringLiteral("-i"),
                                        QStringLiteral("/^\\[General\\]/a DeviceID = bluetooth:004C:0000:0000"),
                                        QStringLiteral("/etc/bluetooth/main.conf")});
}

QString Backend::exportLog()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty())
        dir = QDir::homePath();
    const QString path = dir + QStringLiteral("/pinna-gunluk-%1.txt").arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmm")));
    QProcess p;
    p.start(QStringLiteral("journalctl"), {"--user", "-u", "pinnad", "--no-pager", "-n", "3000", "-o", "short-iso"});
    p.waitForFinished(5000);
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly)) {
        emit error(QStringLiteral("file"), tr("Couldn't write the log to %1.").arg(path));
        return {};
    }
    f.write("Pinna " + version().toUtf8() + "\n\n");
    f.write(QJsonDocument::fromVariant(m_state).toJson());
    f.write("\n");
    f.write(p.readAllStandardOutput());
    emit notice(tr("Log saved: %1").arg(path));
    return path;
}

void Backend::copy(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

// the tray may show up later, so ask every time
bool Backend::trayAvailable() const
{
    if (!m_tray)
        return false;
    // Qt misses the tray in some sessions; ask the StatusNotifier host directly
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.StatusNotifierWatcher"), QStringLiteral("/StatusNotifierWatcher"),
                                              QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    msg.setArguments({QStringLiteral("org.kde.StatusNotifierWatcher"), QStringLiteral("IsStatusNotifierHostRegistered")});
    const auto r = QDBusConnection::sessionBus().call(msg, QDBus::Block, 300);
    return r.type() == QDBusMessage::ReplyMessage ? r.arguments().value(0).value<QDBusVariant>().variant().toBool()
                                                  : QSystemTrayIcon::isSystemTrayAvailable();
}

QString Backend::version() const { return QCoreApplication::applicationVersion(); }

void Backend::startDaemon()
{
    // the systemd service first, otherwise run it directly
    if (QProcess::execute(QStringLiteral("systemctl"), {"--user", "restart", "pinnad.service"}) != 0)
        QProcess::startDetached(QStringLiteral("pinnad"), {});
}

void Backend::openSettings()
{
    QProcess::startDetached(QCoreApplication::applicationFilePath(), {});
}

void Backend::fakeCall(const QString &method, const QVariantList &args)
{
    const QString a = args.value(0).toString();
    auto val = [](const QString &v) -> QVariant {
        if (v == QLatin1String("true") || v == QLatin1String("false"))
            return v == QLatin1String("true");
        bool ok;
        int n = v.toInt(&ok);
        return ok ? QVariant(n) : QVariant(v);
    };
    m_pending.clear();
    if (method == QLatin1String("SetSetting") || method == QLatin1String("SetPref")) {
        const QString group = method == QLatin1String("SetSetting") ? QStringLiteral("settings") : QStringLiteral("prefs");
        auto m = m_state.value(group).toMap();
        m[a] = val(args.value(1).toString());
        m_state[group] = m;
    } else if (method == QLatin1String("Connect") || method == QLatin1String("Disconnect")) {
        m_state[QStringLiteral("connected")] = method == QLatin1String("Connect");
    }
    emit stateChanged();
}
