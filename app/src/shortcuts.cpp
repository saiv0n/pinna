#include "shortcuts.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusVariant>
#include <QRandomGenerator>

static const QString PORTAL = QStringLiteral("org.freedesktop.portal.Desktop");
static const QString DESKTOP = QStringLiteral("/org/freedesktop/portal/desktop");
static const QString IFACE = QStringLiteral("org.freedesktop.portal.GlobalShortcuts");

struct PortalShortcut
{
    QString id;
    QVariantMap props;
};
Q_DECLARE_METATYPE(PortalShortcut)

QDBusArgument &operator<<(QDBusArgument &a, const PortalShortcut &s)
{
    a.beginStructure();
    a << s.id << s.props;
    a.endStructure();
    return a;
}

const QDBusArgument &operator>>(const QDBusArgument &a, PortalShortcut &s)
{
    a.beginStructure();
    a >> s.id >> s.props;
    a.endStructure();
    return a;
}

static QString token() { return QStringLiteral("pinna%1").arg(QRandomGenerator::global()->generate()); }

Shortcuts::Shortcuts(QObject *parent) : QObject(parent)
{
    qDBusRegisterMetaType<PortalShortcut>();
    qDBusRegisterMetaType<QList<PortalShortcut>>();
    auto bus = QDBusConnection::sessionBus();
    bus.connect(PORTAL, DESKTOP, IFACE, QStringLiteral("Activated"), this,
                SLOT(onActivated(QDBusObjectPath, QString, qulonglong, QVariantMap)));

    const QString t = token();
    request(t, SLOT(onCreated(uint, QVariantMap)));
    auto m = QDBusMessage::createMethodCall(PORTAL, DESKTOP, IFACE, QStringLiteral("CreateSession"));
    m.setArguments({QVariantMap{{QStringLiteral("handle_token"), t}, {QStringLiteral("session_handle_token"), token()}}});
    bus.asyncCall(m);
}

Shortcuts::~Shortcuts()
{
    if (!m_session.isEmpty())
        QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(
            PORTAL, m_session, QStringLiteral("org.freedesktop.portal.Session"), QStringLiteral("Close")));
}

bool Shortcuts::supported()
{
    auto m = QDBusMessage::createMethodCall(PORTAL, DESKTOP, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    m.setArguments({IFACE, QStringLiteral("version")});
    return QDBusConnection::sessionBus().call(m, QDBus::Block, 500).type() == QDBusMessage::ReplyMessage;
}

// the reply arrives as a Response signal on a path built from our bus name and the token
void Shortcuts::request(const QString &t, const char *slot)
{
    QString sender = QDBusConnection::sessionBus().baseService().mid(1).replace(QLatin1Char('.'), QLatin1Char('_'));
    const QString path = QStringLiteral("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, t);
    QDBusConnection::sessionBus().connect(PORTAL, path, QStringLiteral("org.freedesktop.portal.Request"),
                                          QStringLiteral("Response"), this, slot);
}

void Shortcuts::onCreated(uint code, const QVariantMap &results)
{
    if (code != 0) {
        qWarning("pinna: the portal refused a shortcut session (%u)", code);
        return;
    }
    m_session = results.value(QStringLiteral("session_handle")).toString();
    auto item = [](const QString &id, const QString &text) {
        return PortalShortcut{id, {{QStringLiteral("description"), text}}};
    };
    QList<PortalShortcut> list{
        item(QStringLiteral("cycle"), tr("Switch to the next listening mode")),
        item(QStringLiteral("anc"), tr("Noise cancellation")),
        item(QStringLiteral("transparency"), tr("Transparency")),
        item(QStringLiteral("adaptive"), tr("Adaptive")),
        item(QStringLiteral("card"), tr("Show the battery card")),
    };
    list.first().props.insert(QStringLiteral("preferred_trigger"), QStringLiteral("CTRL+SHIFT+F12"));

    const QString t = token();
    request(t, SLOT(onBound(uint, QVariantMap)));
    auto m = QDBusMessage::createMethodCall(PORTAL, DESKTOP, IFACE, QStringLiteral("BindShortcuts"));
    m.setArguments({QVariant::fromValue(QDBusObjectPath(m_session)), QVariant::fromValue(list), QString(),
                    QVariantMap{{QStringLiteral("handle_token"), t}}});
    QDBusConnection::sessionBus().asyncCall(m);
}

void Shortcuts::onBound(uint code, const QVariantMap &)
{
    if (code != 0)
        qWarning("pinna: shortcuts were not bound (%u)", code);
}

void Shortcuts::onActivated(const QDBusObjectPath &session, const QString &id, qulonglong, const QVariantMap &)
{
    if (session.path() == m_session)
        emit activated(id);
}
