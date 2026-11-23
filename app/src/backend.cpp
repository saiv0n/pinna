#include "backend.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QJsonDocument>
#include <QCoreApplication>
#include <QProcess>

static const QString SERVICE = QStringLiteral("dev.earshot.Daemon");
static const QString PATH = QStringLiteral("/dev/earshot/Daemon");
static const QString IFACE = QStringLiteral("dev.earshot.Daemon1");

static QString str(const QVariant &v)
{
    if (v.typeId() == QMetaType::Bool)
        return v.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    return v.toString();
}

Backend::Backend(QObject *parent) : QObject(parent)
{
    auto bus = QDBusConnection::sessionBus();
    bus.connect(SERVICE, PATH, IFACE, QStringLiteral("StateChanged"), this, SLOT(onState(QString)));
    bus.connect(SERVICE, PATH, IFACE, QStringLiteral("CaseOpened"), this, SLOT(onCase(QString)));

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

void Backend::onState(const QString &json)
{
    m_state = QJsonDocument::fromJson(json.toUtf8()).toVariant().toMap();
    emit stateChanged();
}

void Backend::onCase(const QString &)
{
    emit caseOpened();
}

void Backend::call(const QString &method, const QVariantList &args)
{
    auto msg = QDBusMessage::createMethodCall(SERVICE, PATH, IFACE, method);
    msg.setArguments(args);
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, 30000), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<> r = *w;
        if (r.isError())
            emit error(r.error().message());
        w->deleteLater();
    });
}

void Backend::setMode(const QString &mode) { call(QStringLiteral("SetMode"), {mode}); }
void Backend::setSetting(const QString &key, const QVariant &value) { call(QStringLiteral("SetSetting"), {key, str(value)}); }
void Backend::setPref(const QString &key, const QVariant &value) { call(QStringLiteral("SetPref"), {key, str(value)}); }
void Backend::rename(const QString &name) { call(QStringLiteral("Rename"), {name}); }
void Backend::connectDevice() { call(QStringLiteral("Connect"), {}); }
void Backend::disconnectDevice() { call(QStringLiteral("Disconnect"), {}); }

void Backend::startDaemon()
{
    // önce systemd servisi, yoksa doğrudan çalıştır
    if (QProcess::execute(QStringLiteral("systemctl"), {"--user", "start", "earshotd.service"}) != 0)
        QProcess::startDetached(QStringLiteral("earshotd"), {});
}

void Backend::openSettings()
{
    QProcess::startDetached(QCoreApplication::applicationFilePath(), {});
}
