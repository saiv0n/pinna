#include "backend.h"
#include "tray.h"

#include <QApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QElapsedTimer>
#include <QFontDatabase>
#include <QLocale>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <QTranslator>
#include <malloc.h>

static QElapsedTimer startClock;

// Ayar penceresi. Tepsiye inince QML motoru tamamen bırakılır, bellekte sadece tepsi kalır.
class App : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "dev.pinna.App1")
public:
    QQmlApplicationEngine *engine = nullptr;
    QQuickWindow *window = nullptr;
    QString component = QStringLiteral("Main");
    bool reduce = false;
    std::function<void(QQmlApplicationEngine *)> prepare;

    QQuickWindow *load()
    {
        if (engine)
            return window;
        engine = new QQmlApplicationEngine(this);
        engine->rootContext()->setContextProperty(QStringLiteral("pinnaTheme"), qEnvironmentVariable("PINNA_THEME"));
        engine->rootContext()->setContextProperty(QStringLiteral("pinnaPage"), qEnvironmentVariable("PINNA_PAGE"));
        engine->rootContext()->setContextProperty(QStringLiteral("pinnaReduceMotion"), reduce);
        engine->rootContext()->setContextProperty(QStringLiteral("pinnaWidth"), qEnvironmentVariableIntValue("PINNA_SHOT_WIDTH"));
        if (prepare)
            prepare(engine);
        engine->loadFromModule("Pinna", component);
        window = engine->rootObjects().isEmpty() ? nullptr : qobject_cast<QQuickWindow *>(engine->rootObjects().first());
        if (window) {
            if (qEnvironmentVariableIsSet("PINNA_TRACE")) {
                connect(window, &QQuickWindow::frameSwapped, Backend::instance(), &Backend::frameShown, Qt::DirectConnection);
                connect(window, &QQuickWindow::frameSwapped, window, [] {
                    static bool once = false;
                    if (!once) {
                        once = true;
                        qInfo("pinna: ilk kare %lld ms", startClock.elapsed());
                    }
                }, Qt::DirectConnection);
            }
            connect(window, &QWindow::visibleChanged, this, [this](bool v) { Backend::instance()->windowShown(v); });
        }
        return window;
    }

    void release()
    {
        if (qEnvironmentVariableIsSet("PINNA_TRACE"))
            qInfo("pinna: pencere bırakılıyor (%s)", engine ? "motor var" : "motor yok");
        if (!engine)
            return;
        engine->deleteLater();
        engine = nullptr;
        window = nullptr;
        Backend::instance()->windowShown(false);
        // silinen arayüzün belleği işletim sistemine geri dönsün
        QTimer::singleShot(1000, [] { malloc_trim(0); });
    }

public slots:
    Q_SCRIPTABLE void Activate()
    {
        if (auto *w = load()) {
            w->show();
            w->raise();
            w->requestActivate();
        }
    }
};

int main(int argc, char *argv[])
{
    startClock.start();
    // tepsi menüsü için Widgets gerekiyor
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Pinna"));
    app.setApplicationVersion(QStringLiteral(PINNA_VERSION));
    app.setOrganizationName(QStringLiteral("pinna"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    const bool popup = app.arguments().contains(QStringLiteral("--popup"));
    const bool hidden = app.arguments().contains(QStringLiteral("--tray"));
    const bool shot = !qEnvironmentVariable("PINNA_SHOT").isEmpty();
    // Hyprland kuralları sınıfa bakıyor, kart ayrı bir sınıfla açılsın
    app.setDesktopFileName(popup ? QStringLiteral("dev.pinna.Popup") : QStringLiteral("dev.pinna.Pinna"));

    App instance;
    instance.component = popup ? QStringLiteral("Popup") : QStringLiteral("Main");
    // ikinci kez açılınca yeni pencere yerine var olanı öne getir
    if (!popup && !shot) {
        auto bus = QDBusConnection::sessionBus();
        if (!bus.registerService(QStringLiteral("dev.pinna.App"))) {
            bus.call(QDBusMessage::createMethodCall(QStringLiteral("dev.pinna.App"), QStringLiteral("/"),
                                                    QStringLiteral("dev.pinna.App1"), QStringLiteral("Activate")));
            return 0;
        }
        bus.registerObject(QStringLiteral("/"), &instance, QDBusConnection::ExportScriptableSlots);
    }

    // kaynak metinler Türkçe; başka dillerde İngilizce çeviri yüklenir
    QTranslator translator;
    auto applyLanguage = [&translator] {
        QString lang = qEnvironmentVariable("PINNA_LANG", Backend::instance()->language());
        if (lang.isEmpty())
            lang = QLocale::system().uiLanguages().value(0, QLocale::system().name());
        QCoreApplication::removeTranslator(&translator);
        if (lang.startsWith(QLatin1String("tr")) && translator.load(QStringLiteral(":/i18n/pinna_tr.qm")))
            QCoreApplication::installTranslator(&translator);
    };
    applyLanguage();
    QObject::connect(Backend::instance(), &Backend::languageChanged, &instance, [&] {
        applyLanguage();
        if (instance.engine)
            instance.engine->retranslate();
    });

    int id = QFontDatabase::addApplicationFont(QStringLiteral(":/qt/qml/Pinna/fonts/Inter.ttf"));
    if (id >= 0) {
        QFont f(QFontDatabase::applicationFontFamilies(id).value(0));
        f.setPixelSize(13);
        f.setHintingPreference(QFont::PreferNoHinting);
        app.setFont(f);
    }

    // GNOME'da animasyonlar kapalıysa hareketleri sadeleştir; açılışı bekletmesin diye arka planda sorulur
    if (qEnvironmentVariableIsSet("PINNA_REDUCE_MOTION")) {
        instance.reduce = qEnvironmentVariableIntValue("PINNA_REDUCE_MOTION") != 0;
    } else {
        auto *p = new QProcess(&app);
        QObject::connect(p, &QProcess::finished, &instance, [p, &instance] {
            instance.reduce = p->readAllStandardOutput().trimmed() == "false";
            if (instance.engine)
                instance.engine->rootContext()->setContextProperty(QStringLiteral("pinnaReduceMotion"), instance.reduce);
            p->deleteLater();
        });
        p->start(QStringLiteral("gsettings"), {"get", "org.gnome.desktop.interface", "enable-animations"});
    }

    if (int h = qEnvironmentVariableIntValue("PINNA_SHOT_HEIGHT"))
        instance.prepare = [h](QQmlApplicationEngine *e) { e->setInitialProperties({{QStringLiteral("height"), h}}); };

    if (!popup && !shot) {
        auto *tray = new Tray(&app);
        tray->open = [&instance] { instance.Activate(); };
        tray->isOpen = [&instance] { return instance.window && instance.window->isVisible() && instance.window->isActive(); };
        tray->close = [&instance] { instance.release(); };
        Backend::instance()->setTray(true);
        app.setQuitOnLastWindowClosed(false);
        // QML pencereyi tepsiye indirince motoru bırak
        QObject::connect(Backend::instance(), &Backend::windowReleased, &instance, [&instance] { instance.release(); });
        if (hidden && tray->available())
            return app.exec();
    }

    QQuickWindow *window = instance.load();
    if (!window)
        return 1;
    window->show();

    // README görselleri için: PINNA_SHOT=dosya.png ile pencereyi kaydedip çık
    if (shot) {
        const QString path = qEnvironmentVariable("PINNA_SHOT");
        QTimer::singleShot(qEnvironmentVariableIntValue("PINNA_SHOT_DELAY") ?: 2500, window, [window, path] {
            window->grabWindow().save(path);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}

#include "main.moc"
