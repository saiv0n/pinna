#pragma once

#include <QObject>
#include <functional>

class QSystemTrayIcon;
class QMenu;

// StatusNotifierItem olarak görünen tepsi simgesi; menüsü servis durumundan kurulur.
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
};
