#pragma once

#include <QDBusObjectPath>
#include <QObject>
#include <QVariantMap>

// Global shortcuts through xdg-desktop-portal, so they work on Wayland without compositor config
class Shortcuts : public QObject
{
    Q_OBJECT
public:
    explicit Shortcuts(QObject *parent = nullptr);
    ~Shortcuts() override;
    static bool supported();

signals:
    void activated(const QString &id);

private slots:
    void onCreated(uint code, const QVariantMap &results);
    void onBound(uint code, const QVariantMap &results);
    void onActivated(const QDBusObjectPath &session, const QString &id, qulonglong timestamp, const QVariantMap &options);

private:
    void request(const QString &token, const char *slot);
    QString m_session;
};
