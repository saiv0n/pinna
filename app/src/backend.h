#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QDBusServiceWatcher;
class QQmlEngine;
class QJSEngine;

// pinnad ile D-Bus üzerinden konuşan köprü. Durumun tamamı tek bir harita olarak QML'e açılıyor.
class Backend : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool daemon READ daemon NOTIFY daemonChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(QVariantList head READ head NOTIFY headChanged)
    Q_PROPERTY(bool closeToTray READ closeToTray WRITE setCloseToTray NOTIFY appChanged)
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY appChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool trayAvailable MEMBER m_tray NOTIFY appChanged)
    Q_PROPERTY(bool deviceIdOk READ deviceIdOk NOTIFY appChanged)
    Q_PROPERTY(QString deviceIdCommand READ deviceIdCommand CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)

public:
    explicit Backend(QObject *parent = nullptr);
    static Backend *instance();
    static Backend *create(QQmlEngine *, QJSEngine *) { return instance(); }

    QVariantMap state() const { return m_state; }
    bool daemon() const { return m_daemon; }
    QVariantList history() const { return m_history; }
    QVariantList head() const { return m_head; }
    bool closeToTray() const;
    void setCloseToTray(bool on);
    bool autostart() const;
    void setAutostart(bool on);
    bool deviceIdOk() const;
    QString language() const;
    void setLanguage(const QString &lang);
    QString deviceIdCommand() const;
    QString version() const;
    void setTray(bool on) { m_tray = on; emit appChanged(); }
    void frameShown();

    Q_INVOKABLE void setMode(const QString &mode);
    Q_INVOKABLE void setSetting(const QString &key, const QVariant &value);
    Q_INVOKABLE void setPref(const QString &key, const QVariant &value);
    Q_INVOKABLE void setAudio(const QString &key, const QVariant &value);
    Q_INVOKABLE void rename(const QString &name);
    Q_INVOKABLE void connectDevice();
    Q_INVOKABLE void disconnectDevice();
    Q_INVOKABLE void select(const QString &address);
    Q_INVOKABLE void forget(const QString &address);
    Q_INVOKABLE void discover(bool on);
    Q_INVOKABLE void pair(const QString &address);
    Q_INVOKABLE void headTracking(bool on);
    Q_INVOKABLE void loadHistory();
    Q_INVOKABLE void startDaemon();
    Q_INVOKABLE void openSettings();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setupDeviceId();
    Q_INVOKABLE QString exportLog();
    Q_INVOKABLE void copy(const QString &text);

signals:
    void stateChanged();
    void daemonChanged();
    void historyChanged();
    void headChanged();
    void appChanged();
    void languageChanged();
    void error(const QString &message);
    void notice(const QString &message);
    void caseOpened();

private slots:
    void onState(const QString &json);
    void onCase(const QString &json);
    void onHead(const QList<qint16> &values);

private:
    void call(const QString &method, const QVariantList &args);
    void optimistic(const QString &group, const QString &key, const QVariant &value);
    void setDaemon(bool up);
    void fakeCall(const QString &method, const QVariantList &args);

    struct Pending {
        QString group, key;
        QVariant value;
        qint64 at;
    };
    QList<Pending> m_pending;
    QElapsedTimer m_clock;
    qint64 m_traceAt = -1;
    bool m_trace = false;

    QVariantMap m_state;
    QVariantList m_history;
    QVariantList m_head;
    bool m_daemon = false;
    bool m_tray = false;
    QString m_fake;
    QDBusServiceWatcher *m_watcher = nullptr;
};
