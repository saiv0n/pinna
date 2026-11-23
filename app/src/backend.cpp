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
#include <QDateTime>
#include <QDir>
#include <QGuiApplication>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>

static const QString SERVICE = QStringLiteral("dev.pinna.Daemon");
static const QString PATH = QStringLiteral("/dev/pinna/Daemon");
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

// QML'e de tepsiye de aynı nesne gitsin diye
Backend::Backend(QObject *parent) : QObject(parent)
{
    m_clock.start();
    m_trace = qEnvironmentVariableIsSet("PINNA_TRACE");
    // ekran görüntüsü ve tasarım denemeleri için servis yerine dosyadan oku
    m_fake = qEnvironmentVariable("PINNA_STATE");
    if (!m_fake.isEmpty()) {
        QFile f(m_fake);
        if (f.open(QIODevice::ReadOnly))
            onState(QString::fromUtf8(f.readAll()));
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
            onState(r.value());
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
    qInfo("pinna: tıklamadan ekrana %.2f ms", (m_clock.nsecsElapsed() - m_traceAt) / 1e6);
    m_traceAt = -1;
}

void Backend::onState(const QString &json)
{
    auto next = QJsonDocument::fromJson(json.toUtf8()).toVariant().toMap();
    // tıklanan değer kulaklıktan onay gelene kadar ekranda kalsın, eski bir yankı geri çevirmesin
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
            emit error(r.error().message());
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
    if (!m_fake.isEmpty())
        return;
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

// boş değer sistem dili demek
QString Backend::language() const { return QSettings().value(QStringLiteral("language")).toString(); }

void Backend::setLanguage(const QString &lang)
{
    QSettings().setValue(QStringLiteral("language"), lang);
    emit languageChanged();
}

bool Backend::autostart() const { return QFile::exists(autostartFile()); }

void Backend::setAutostart(bool on)
{
    if (on) {
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

QString Backend::deviceIdCommand() const
{
    return QStringLiteral(R"(pkexec sh -c "sed -i '/^\[General\]/a DeviceID = bluetooth:004C:0000:0000' /etc/bluetooth/main.conf && systemctl restart bluetooth")");
}

void Backend::setupDeviceId()
{
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p](int code) {
        if (code == 0)
            emit notice(tr("DeviceID eklendi, Bluetooth yeniden başlatıldı."));
        else
            emit error(tr("DeviceID eklenemedi (çıkış kodu %1).").arg(code));
        emit appChanged();
        p->deleteLater();
    });
    p->start(QStringLiteral("sh"), {QStringLiteral("-c"), deviceIdCommand()});
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
        emit error(tr("Günlük yazılamadı: %1").arg(path));
        return {};
    }
    f.write("Pinna " + version().toUtf8() + "\n\n");
    f.write(QJsonDocument::fromVariant(m_state).toJson());
    f.write("\n");
    f.write(p.readAllStandardOutput());
    emit notice(tr("Günlük kaydedildi: %1").arg(path));
    return path;
}

void Backend::copy(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

QString Backend::version() const { return QCoreApplication::applicationVersion(); }

void Backend::startDaemon()
{
    // önce systemd servisi, yoksa doğrudan çalıştır
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
