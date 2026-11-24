#include "tray.h"
#include "backend.h"

#include <QActionGroup>
#include <QCoreApplication>
#include <QMenu>
#include <QPainter>
#include <QSystemTrayIcon>

static QString level(const QVariantMap &bat, const QString &k)
{
    const auto c = bat.value(k).toMap();
    if (c.value(QStringLiteral("level")).isNull())
        return {};
    return QStringLiteral("%1%").arg(c.value(QStringLiteral("level")).toInt());
}

// The buds with a small ring for the lower bud, so the level shows without opening anything.
// level < 0 is the plain icon.
static QIcon trayIcon(int level, bool charging)
{
    QPixmap base(QStringLiteral(":/qt/qml/Pinna/assets/tray.png"));
    if (level < 0)
        return QIcon(base);
    QPixmap pm = base.scaled(64, 64, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing);
    const QRectF r(36, 36, 26, 26);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(20, 20, 22, 230));
    p.drawEllipse(r);
    const QColor c = charging ? QColor(52, 199, 89) : level <= 10 ? QColor(255, 69, 58) : level <= 20 ? QColor(255, 159, 10) : QColor(52, 199, 89);
    QPen track(QColor(255, 255, 255, 60), 4);
    p.setPen(track);
    p.setBrush(Qt::NoBrush);
    const QRectF ring = r.adjusted(4, 4, -4, -4);
    p.drawEllipse(ring);
    QPen arc(c, 4);
    arc.setCapStyle(Qt::RoundCap);
    p.setPen(arc);
    p.drawArc(ring, 90 * 16, -int(360 * 16 * qBound(0, level, 100) / 100.0));
    return QIcon(pm);
}

Tray::Tray(QObject *parent) : QObject(parent)
{
    m_menu = new QMenu();
    m_icon = new QSystemTrayIcon(QIcon(QStringLiteral(":/qt/qml/Pinna/assets/tray.png")), this);
    m_icon->setContextMenu(m_menu);
    connect(m_icon, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason r) {
        if (r == QSystemTrayIcon::Trigger)
            toggleWindow();
    });
    connect(Backend::instance(), &Backend::stateChanged, this, &Tray::rebuild);
    connect(Backend::instance(), &Backend::daemonChanged, this, &Tray::rebuild);
    rebuild();
    m_icon->show();
}

bool Tray::available() const { return QSystemTrayIcon::isSystemTrayAvailable(); }

void Tray::toggleWindow()
{
    if (isOpen && isOpen())
        close();
    else if (open)
        open();
}

void Tray::rebuild()
{
    if (m_menu->isVisible())
        return;
    auto *b = Backend::instance();
    const auto s = b->state();
    const bool live = b->daemon() && s.value(QStringLiteral("connected")).toBool();
    const QString name = s.value(QStringLiteral("name")).toString().isEmpty() ? QStringLiteral("AirPods") : s.value(QStringLiteral("name")).toString();
    const auto bat = s.value(QStringLiteral("battery")).toMap();

    QStringList parts;
    const QString l = level(bat, QStringLiteral("left")), r = level(bat, QStringLiteral("right")), c = level(bat, QStringLiteral("case"));
    if (!l.isEmpty())
        parts << (s.value(QStringLiteral("oneBattery")).toBool() ? tr("Battery %1") : tr("Left %1")).arg(l);
    if (!r.isEmpty())
        parts << tr("Right %1").arg(r);
    if (!c.isEmpty())
        parts << tr("Case %1").arg(c);
    const QString status = !b->daemon() ? tr("Service not running")
        : !s.value(QStringLiteral("adapter")).toBool() ? tr("Bluetooth is off")
        // the case advert still tells the levels while they are not connected
        : !live ? (parts.isEmpty() ? tr("Not connected") : tr("Not connected") + QStringLiteral("\n") + parts.join(QStringLiteral("  ")))
        : parts.join(QStringLiteral("  "));
    // the lower of the two estimates, since the first bud to run out ends listening
    QString left;
    if (live) {
        const auto est = s.value(QStringLiteral("estimate")).toMap();
        const auto bat = s.value(QStringLiteral("battery")).toMap();
        int m = -1;
        for (const auto &k : {QStringLiteral("left"), QStringLiteral("right")}) {
            // a charging bud's estimate is time to full
            if (bat.value(k).toMap().value(QStringLiteral("charging")).toBool())
                continue;
            const auto v = est.value(k);
            if (v.isValid() && !v.isNull() && (m < 0 || v.toInt() < m))
                m = v.toInt();
        }
        if (m > 0)
            left = m < 60 ? tr("%1 min left").arg(m)
                : m % 60 == 0 ? tr("%1 h left").arg(m / 60)
                : tr("%1 h %2 min left").arg(m / 60).arg(m % 60);
    }
    // other paired headphones heard nearby, so two pairs are never mixed up (LibrePods #670)
    const QString selected = s.value(QStringLiteral("address")).toString();
    const auto devices = s.value(QStringLiteral("devices")).toList();
    QStringList others;
    for (const auto &v : devices) {
        const auto d = v.toMap();
        const auto last = d.value(QStringLiteral("last")).toMap();
        if (d.value(QStringLiteral("address")).toString().compare(selected, Qt::CaseInsensitive) == 0 || last.isEmpty())
            continue;
        QStringList p;
        for (const auto &[k, label] : {std::pair{QStringLiteral("left"), tr("L")}, {QStringLiteral("right"), tr("R")}, {QStringLiteral("case"), tr("Case")}}) {
            if (!last.value(k).isNull())
                p << QStringLiteral("%1 %2%").arg(label).arg(last.value(k).toInt());
        }
        if (!p.isEmpty())
            others << d.value(QStringLiteral("name")).toString() + QStringLiteral(": ") + p.join(QStringLiteral("  "));
    }
    QString tip = name + QStringLiteral("\n") + status + (left.isEmpty() ? QString() : QStringLiteral("\n") + left);
    if (!others.isEmpty())
        tip += QStringLiteral("\n\n") + others.join(QStringLiteral("\n"));
    m_icon->setToolTip(tip);
    int low = -1;
    bool charging = false;
    if (live) {
        for (const auto &k : {QStringLiteral("left"), QStringLiteral("right")}) {
            const auto c = bat.value(k).toMap();
            if (c.value(QStringLiteral("level")).isNull())
                continue;
            const int v = c.value(QStringLiteral("level")).toInt();
            if (low < 0 || v < low) {
                low = v;
                charging = c.value(QStringLiteral("charging")).toBool();
            }
        }
    }
    // redraw only when the picture would change
    const int key = low < 0 ? -1 : low * 2 + charging;
    if (key != m_iconKey) {
        m_iconKey = key;
        m_icon->setIcon(trayIcon(low, charging));
    }
    if (qEnvironmentVariableIsSet("PINNA_TRAY_SHOT"))
        trayIcon(low < 0 ? 15 : low, charging).pixmap(64, 64).save(qEnvironmentVariable("PINNA_TRAY_SHOT"));

    m_menu->clear();
    m_menu->addAction(name)->setEnabled(false);
    m_menu->addAction(status)->setEnabled(false);
    if (!left.isEmpty())
        m_menu->addAction(left)->setEnabled(false);
    m_menu->addSeparator();

    const QString mode = s.value(QStringLiteral("mode")).toString();
    if (live) {
        const bool allowOff = s.value(QStringLiteral("settings")).toMap().value(QStringLiteral("allowOff"), true).toBool();
        auto *group = new QActionGroup(m_menu);
        const QList<QPair<QString, QString>> modes = {
            {QStringLiteral("off"), tr("Off")},
            {QStringLiteral("transparency"), tr("Transparency")},
            {QStringLiteral("adaptive"), tr("Adaptive")},
            {QStringLiteral("anc"), tr("Noise Cancellation")},
        };
        // models without listening modes never report one
        for (const auto &[key, label] : mode.isEmpty() ? decltype(modes){} : modes) {
            if (key == QLatin1String("off") && !allowOff && mode != key)
                continue;
            // same rule as the app: no adaptive mode on models that never report its strength
            if (key == QLatin1String("adaptive") && mode != key && s.value(QStringLiteral("ready")).toBool()
                && !s.value(QStringLiteral("settings")).toMap().contains(QStringLiteral("adaptiveStrength")))
                continue;
            auto *a = m_menu->addAction(label);
            a->setCheckable(true);
            a->setChecked(mode == key);
            a->setActionGroup(group);
            connect(a, &QAction::triggered, b, [b, key] { b->setMode(key); });
        }
        if (!mode.isEmpty())
            m_menu->addSeparator();
        connect(m_menu->addAction(tr("Disconnect")), &QAction::triggered, b, &Backend::disconnectDevice);
    } else if (b->daemon() && !s.value(QStringLiteral("adapter")).toBool()) {
        connect(m_menu->addAction(tr("Turn On Bluetooth")), &QAction::triggered, b, &Backend::powerOn);
    } else if (b->daemon()) {
        connect(m_menu->addAction(tr("Connect")), &QAction::triggered, b, &Backend::connectDevice);
    } else {
        connect(m_menu->addAction(tr("Start Service")), &QAction::triggered, b, &Backend::startDaemon);
    }
    if (b->daemon() && devices.size() > 1) {
        auto *sub = m_menu->addMenu(tr("Headphones"));
        auto *group = new QActionGroup(sub);
        for (const auto &v : devices) {
            const auto d = v.toMap();
            const QString addr = d.value(QStringLiteral("address")).toString();
            auto *a = sub->addAction(d.value(QStringLiteral("name")).toString());
            a->setCheckable(true);
            a->setChecked(addr.compare(selected, Qt::CaseInsensitive) == 0);
            a->setActionGroup(group);
            connect(a, &QAction::triggered, b, [b, addr] { b->select(addr); });
        }
    }
    connect(m_menu->addAction(tr("Open Settings")), &QAction::triggered, this, [this] {
        if (open)
            open();
    });
    m_menu->addSeparator();
    connect(m_menu->addAction(tr("Quit")), &QAction::triggered, qApp, &QCoreApplication::quit);
}
