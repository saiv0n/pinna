#include "backend.h"
#include "tray.h"

#include <QAnimationDriver>
#include <QApplication>
#include <QFile>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QElapsedTimer>
#include <QFontDatabase>
#include <QLocale>
#include <QProcess>
#include <QSettings>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <QTranslator>
#include <malloc.h>

static QElapsedTimer startClock;

// Animation time that moves exactly one frame per grab, so a recording is smooth however slow the grab is.
class StepDriver : public QAnimationDriver
{
public:
    qint64 now = 0;
    qint64 elapsed() const override { return now; }
    void step(qint64 to) { now = to; advance(); }
};

// PINNA_RECORD=out.mkv renders PINNA_RECORD_SECONDS of the window at 60 fps into a lossless video.
// PINNA_RECORD_SCRIPT lines are "seconds action argument" and go to demo() in QML.
static void record(QQuickWindow *window)
{
    struct Step { double at; QString action, arg; };
    QList<Step> steps;
    QFile f(qEnvironmentVariable("PINNA_RECORD_SCRIPT"));
    if (f.open(QIODevice::ReadOnly)) {
        for (const QString &line : QString::fromUtf8(f.readAll()).split(QLatin1Char('\n'))) {
            const QStringList p = line.simplified().split(QLatin1Char(' '));
            if (p.size() >= 2 && !line.startsWith(QLatin1Char('#')))
                steps << Step{p[0].toDouble(), p[1], p.value(2)};
        }
    }
    auto *driver = new StepDriver;
    driver->install();
    driver->step(0);
    const QImage first = window->grabWindow();
    auto *ffmpeg = new QProcess;
    ffmpeg->start(QStringLiteral("ffmpeg"), {"-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
        "-s", QStringLiteral("%1x%2").arg(first.width()).arg(first.height()), "-r", "60", "-i", "-",
        "-c:v", "libx264rgb", "-qp", "0", "-preset", "ultrafast", qEnvironmentVariable("PINNA_RECORD")});
    ffmpeg->waitForStarted();
    const int frames = qRound(qEnvironmentVariable("PINNA_RECORD_SECONDS", QStringLiteral("5")).toDouble() * 60);
    for (int n = 0; n < frames; ++n) {
        const double t = n / 60.0;
        while (!steps.isEmpty() && steps.first().at <= t) {
            const Step s = steps.takeFirst();
            QMetaObject::invokeMethod(window, "demo", Q_ARG(QVariant, s.action), Q_ARG(QVariant, s.arg));
        }
        driver->step(qRound64(t * 1000));
        QCoreApplication::processEvents();
        const QImage img = window->grabWindow().convertToFormat(QImage::Format_RGBA8888);
        ffmpeg->write(reinterpret_cast<const char *>(img.constBits()), img.sizeInBytes());
        ffmpeg->waitForBytesWritten(-1);
    }
    ffmpeg->closeWriteChannel();
    ffmpeg->waitForFinished(-1);
    QCoreApplication::quit();
}

// The settings window. When it goes to the tray the QML engine is dropped and only the tray stays in memory.
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
        engine->rootContext()->setContextProperty(QStringLiteral("pinnaDemo"), qEnvironmentVariable("PINNA_DEMO"));
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
                        qInfo("pinna: first frame after %lld ms", startClock.elapsed());
                    }
                }, Qt::DirectConnection);
            }
            connect(window, &QWindow::visibleChanged, this, [this](bool v) { Backend::instance()->windowShown(v); });
            // the size it had last time; screenshots keep the fixed one
            const QSize size = QSettings().value(QStringLiteral("windowSize")).toSize();
            if (component == QLatin1String("Main") && size.isValid() && qEnvironmentVariable("PINNA_SHOT").isEmpty())
                window->resize(size.expandedTo(window->minimumSize()));
            if (qEnvironmentVariableIsSet("PINNA_TRACE"))
                qInfo("pinna: window %dx%d", window->width(), window->height());
        }
        return window;
    }

    void saveSize()
    {
        if (window && component == QLatin1String("Main") && qEnvironmentVariable("PINNA_SHOT").isEmpty())
            QSettings().setValue(QStringLiteral("windowSize"), window->size());
    }

    void release()
    {
        if (qEnvironmentVariableIsSet("PINNA_TRACE"))
            qInfo("pinna: releasing window (%s)", engine ? "engine alive" : "no engine");
        if (!engine)
            return;
        saveSize();
        engine->deleteLater();
        engine = nullptr;
        window = nullptr;
        Backend::instance()->windowShown(false);
        // give the memory of the dropped UI back to the OS
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
    // the tray menu needs Widgets
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Pinna"));
    app.setApplicationVersion(QStringLiteral(PINNA_VERSION));
    app.setOrganizationName(QStringLiteral("pinna"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    const bool popup = app.arguments().contains(QStringLiteral("--popup"));
    const bool hidden = app.arguments().contains(QStringLiteral("--tray"));
    const bool shot = !qEnvironmentVariable("PINNA_SHOT").isEmpty() || !qEnvironmentVariable("PINNA_RECORD").isEmpty();
    // Hyprland rules match the class, so the card gets its own
    app.setDesktopFileName(popup ? QStringLiteral("dev.pinna.Popup") : QStringLiteral("dev.pinna.Pinna"));

    App instance;
    instance.component = popup ? QStringLiteral("Popup") : QStringLiteral("Main");
    // a second launch raises the existing window
    if (!popup && !shot) {
        auto bus = QDBusConnection::sessionBus();
        if (!bus.registerService(QStringLiteral("dev.pinna.App"))) {
            bus.call(QDBusMessage::createMethodCall(QStringLiteral("dev.pinna.App"), QStringLiteral("/"),
                                                    QStringLiteral("dev.pinna.App1"), QStringLiteral("Activate")));
            return 0;
        }
        bus.registerObject(QStringLiteral("/"), &instance, QDBusConnection::ExportScriptableSlots);
    }

    // source strings are English; other languages load from :/i18n/pinna_<lang>.qm
    QTranslator translator;
    auto applyLanguage = [&translator] {
        QString lang = qEnvironmentVariable("PINNA_LANG", Backend::instance()->language());
        if (lang.isEmpty())
            lang = QLocale::system().uiLanguages().value(0, QLocale::system().name());
        QCoreApplication::removeTranslator(&translator);
        // "pt_BR" tries pinna_pt_BR, then pinna_pt
        lang = lang.section(QLatin1Char('.'), 0, 0).replace(QLatin1Char('-'), QLatin1Char('_'));
        for (const QString &code : {lang, lang.section(QLatin1Char('_'), 0, 0)}) {
            if (translator.load(QStringLiteral(":/i18n/pinna_%1.qm").arg(code))) {
                QCoreApplication::installTranslator(&translator);
                break;
            }
        }
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

    // reduce motion when GNOME animations are off; asked in the background so startup does not wait
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

    QObject::connect(&app, &QCoreApplication::aboutToQuit, &instance, [&instance] { instance.saveSize(); });
    if (!popup && !shot) {
        auto *tray = new Tray(&app);
        tray->open = [&instance] { instance.Activate(); };
        tray->isOpen = [&instance] { return instance.window && instance.window->isVisible() && instance.window->isActive(); };
        tray->close = [&instance] { instance.release(); };
        Backend::instance()->setTray(true);
        if (Backend::instance()->globalShortcuts())
            Backend::instance()->setGlobalShortcuts(true);
        app.setQuitOnLastWindowClosed(false);
        // drop the engine when QML sends the window to the tray
        QObject::connect(Backend::instance(), &Backend::windowReleased, &instance, [&instance] { instance.release(); });
        if (hidden && tray->available())
            return app.exec();
        if (hidden)
            qWarning("pinna: no system tray found (it needs a StatusNotifierItem host), showing the window instead");
    }

    QQuickWindow *window = instance.load();
    if (!window)
        return 1;
    window->show();

    // for README images: PINNA_SHOT=file.png saves the window and quits
    if (!qEnvironmentVariable("PINNA_SHOT").isEmpty()) {
        const QString path = qEnvironmentVariable("PINNA_SHOT");
        QTimer::singleShot(qEnvironmentVariableIntValue("PINNA_SHOT_DELAY") ?: 2500, window, [window, path] {
            window->grabWindow().save(path);
            QCoreApplication::quit();
        });
    }
    if (!qEnvironmentVariable("PINNA_RECORD").isEmpty())
        QTimer::singleShot(1500, window, [window] { record(window); });
    return app.exec();
}

#include "main.moc"
