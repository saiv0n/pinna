#pragma once

#include <QObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QDBusServiceWatcher;

// earshotd ile D-Bus üzerinden konuşan köprü. Durumun tamamı tek bir harita olarak QML'e açılıyor.
class Backend : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool daemon READ daemon NOTIFY daemonChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    QVariantMap state() const { return m_state; }
    bool daemon() const { return m_daemon; }

    Q_INVOKABLE void setMode(const QString &mode);
    Q_INVOKABLE void setSetting(const QString &key, const QVariant &value);
    Q_INVOKABLE void setPref(const QString &key, const QVariant &value);
    Q_INVOKABLE void rename(const QString &name);
    Q_INVOKABLE void connectDevice();
    Q_INVOKABLE void disconnectDevice();
    Q_INVOKABLE void startDaemon();
    Q_INVOKABLE void openSettings();
    Q_INVOKABLE void refresh();

signals:
    void stateChanged();
    void daemonChanged();
    void error(const QString &message);
    void caseOpened();

private slots:
    void onState(const QString &json);
    void onCase(const QString &json);

private:
    void call(const QString &method, const QVariantList &args);
    void setDaemon(bool up);

    QVariantMap m_state;
    bool m_daemon = false;
    QDBusServiceWatcher *m_watcher = nullptr;
};
