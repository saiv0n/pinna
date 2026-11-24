#pragma once

#include <QObject>
#include <functional>

class QSystemTrayIcon;
class QMenu;

// Tray icon as a StatusNotifierItem; its menu is built from the service state.
class Tray : public QObject
{
    Q_OBJECT
public:
    explicit Tray(QObject *parent = nullptr);
    bool available() const;
    std::function<void()> open, close;
    std::function<bool()> isOpen;
    void toggleWindow();

private:
    void rebuild();
    QSystemTrayIcon *m_icon;
    QMenu *m_menu;
    int m_iconKey = -2;
};
