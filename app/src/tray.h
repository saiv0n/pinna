#pragma once

#include <QObject>

class QSystemTrayIcon;
class QMenu;
class QWindow;

// StatusNotifierItem olarak görünen tepsi simgesi; menüsü servis durumundan kurulur.
class Tray : public QObject
{
    Q_OBJECT
public:
    explicit Tray(QObject *parent = nullptr);
    bool available() const;
    QWindow *window = nullptr;
    void toggleWindow();

private:
    void rebuild();
    QSystemTrayIcon *m_icon;
    QMenu *m_menu;
};
