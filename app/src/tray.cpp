#include "tray.h"
#include "backend.h"

#include <QActionGroup>
#include <QCoreApplication>
#include <QMenu>
#include <QSystemTrayIcon>
#include <QWindow>

static QString level(const QVariantMap &bat, const QString &k)
{
    const auto c = bat.value(k).toMap();
    if (c.value(QStringLiteral("level")).isNull())
        return {};
    return QStringLiteral("%1%").arg(c.value(QStringLiteral("level")).toInt());
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
    if (!window)
        return;
    if (window->isVisible() && window->isActive()) {
        window->hide();
    } else {
        window->show();
        window->raise();
        window->requestActivate();
    }
}

void Tray::rebuild()
{
    auto *b = Backend::instance();
    const auto s = b->state();
    const bool live = b->daemon() && s.value(QStringLiteral("connected")).toBool();
    const QString name = s.value(QStringLiteral("name")).toString().isEmpty() ? QStringLiteral("AirPods") : s.value(QStringLiteral("name")).toString();
    const auto bat = s.value(QStringLiteral("battery")).toMap();

    QStringList parts;
    const QString l = level(bat, QStringLiteral("left")), r = level(bat, QStringLiteral("right")), c = level(bat, QStringLiteral("case"));
    if (!l.isEmpty())
        parts << tr("Sol %1").arg(l);
    if (!r.isEmpty())
        parts << tr("Sağ %1").arg(r);
    if (!c.isEmpty())
        parts << tr("Kutu %1").arg(c);
    const QString status = !b->daemon() ? tr("Servis çalışmıyor") : !live ? tr("Bağlı değil") : parts.join(QStringLiteral("  "));
    m_icon->setToolTip(name + QStringLiteral("\n") + status);

    m_menu->clear();
    m_menu->addAction(name)->setEnabled(false);
    m_menu->addAction(status)->setEnabled(false);
    m_menu->addSeparator();

    if (live) {
        const QString mode = s.value(QStringLiteral("mode")).toString();
        const bool allowOff = s.value(QStringLiteral("settings")).toMap().value(QStringLiteral("allowOff"), true).toBool();
        auto *group = new QActionGroup(m_menu);
        const QList<QPair<QString, QString>> modes = {
            {QStringLiteral("off"), tr("Kapalı")},
            {QStringLiteral("transparency"), tr("Şeffaflık")},
            {QStringLiteral("adaptive"), tr("Uyarlanabilir")},
            {QStringLiteral("anc"), tr("Gürültü Engelleme")},
        };
        for (const auto &[key, label] : modes) {
            if (key == QLatin1String("off") && !allowOff && mode != key)
                continue;
            auto *a = m_menu->addAction(label);
            a->setCheckable(true);
            a->setChecked(mode == key);
            a->setActionGroup(group);
            connect(a, &QAction::triggered, b, [b, key] { b->setMode(key); });
        }
        m_menu->addSeparator();
        connect(m_menu->addAction(tr("Bağlantıyı Kes")), &QAction::triggered, b, &Backend::disconnectDevice);
    } else if (b->daemon()) {
        connect(m_menu->addAction(tr("Bağlan")), &QAction::triggered, b, &Backend::connectDevice);
    } else {
        connect(m_menu->addAction(tr("Servisi Başlat")), &QAction::triggered, b, &Backend::startDaemon);
    }
    connect(m_menu->addAction(tr("Ayarları Aç")), &QAction::triggered, this, [this] {
        if (window) {
            window->show();
            window->raise();
            window->requestActivate();
        }
    });
    m_menu->addSeparator();
    connect(m_menu->addAction(tr("Çık")), &QAction::triggered, qApp, &QCoreApplication::quit);
}
