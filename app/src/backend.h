#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QDBusServiceWatcher;
class QQmlEngine;
class QJSEngine;

// Bridge that talks to pinnad over D-Bus. The whole state is exposed to QML as one map.
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
    Q_PROPERTY(bool globalShortcuts READ globalShortcuts WRITE setGlobalShortcuts NOTIFY appChanged)
    Q_PROPERTY(bool shortcutsSupported READ shortcutsSupported NOTIFY appChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool trayAvailable READ trayAvailable NOTIFY appChanged)
    Q_PROPERTY(bool deviceIdOk READ deviceIdOk NOTIFY appChanged)
    Q_PROPERTY(QString deviceIdCommand READ deviceIdCommand CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)

public:
    static Backend *instance();
    // QML uses the same object as the tray; it outlives the engine
    static Backend *create(QQmlEngine *, QJSEngine *);

    QVariantMap state() const { return m_state; }
    bool daemon() const { return m_daemon; }
    QVariantList history() const { return m_history; }
    QVariantList head() const { return m_head; }
    bool closeToTray() const;
    void setCloseToTray(bool on);
    bool autostart() const;
    bool globalShortcuts() const;
    void setGlobalShortcuts(bool on);
    bool shortcutsSupported();
    void setAutostart(bool on);
    bool deviceIdOk() const;
    QString language() const;
    void setLanguage(const QString &lang);
    QString deviceIdCommand() const;
    void windowShown(bool shown) { m_windowShown = shown; }
    QString version() const;
    bool trayAvailable() const;
    void setTray(bool on) { m_tray = on; emit appChanged(); }
    void frameShown();

    Q_INVOKABLE void setMode(const QString &mode);
    Q_INVOKABLE void cycleMode();
    Q_INVOKABLE void setSetting(const QString &key, const QVariant &value);
    Q_INVOKABLE void setPref(const QString &key, const QVariant &value);
    Q_INVOKABLE void setAudio(const QString &key, const QVariant &value);
    Q_INVOKABLE void rename(const QString &name);
    Q_INVOKABLE void connectDevice();
    Q_INVOKABLE void powerOn();
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
    Q_INVOKABLE void releaseWindow() { emit windowReleased(); }

signals:
    void stateChanged();
    void daemonChanged();
    void historyChanged();
    void headChanged();
    void appChanged();
    void languageChanged();
    // kod: not-connected, bluetooth-off, unreachable, service, invalid, audio, pair-failed, busy, bluetooth
    void error(const QString &code, const QString &message);
    void notice(const QString &message);
    void caseOpened();
    void windowReleased();

private:
    explicit Backend(QObject *parent = nullptr);

private slots:
    void onState(const QString &json);
    void replaceState(const QString &json);
    void onCase(const QString &json);
    void onHead(const QList<qint16> &values);

private:
    void call(const QString &method, const QVariantList &args);
    void optimistic(const QString &group, const QString &key, const QVariant &value);
    void setDaemon(bool up);
    void apply(QVariantMap next);
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
    class Shortcuts *m_shortcuts = nullptr;
    int m_shortcutsSupported = -1;
    bool m_tray = false;
    bool m_windowShown = true;
    QString m_fake;
    QDBusServiceWatcher *m_watcher = nullptr;
};
