#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QProcess>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

// İkinci kez açılınca yeni pencere yerine var olanı öne getirmek için.
class Instance : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "dev.pinna.App1")
public:
    QQmlApplicationEngine *engine = nullptr;
public slots:
    Q_SCRIPTABLE void Activate()
    {
        if (!engine || engine->rootObjects().isEmpty())
            return;
        if (auto *w = qobject_cast<QQuickWindow *>(engine->rootObjects().first())) {
            w->show();
            w->raise();
            w->requestActivate();
        }
    }
};

// GNOME ayarlarında animasyonlar kapatıldıysa hareketleri sadeleştir
static bool reduceMotion()
{
    if (qEnvironmentVariableIsSet("PINNA_REDUCE_MOTION"))
        return qEnvironmentVariableIntValue("PINNA_REDUCE_MOTION") != 0;
    QProcess p;
    p.start(QStringLiteral("gsettings"), {"get", "org.gnome.desktop.interface", "enable-animations"});
    if (!p.waitForFinished(400))
        return false;
    return p.readAllStandardOutput().trimmed() == "false";
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Pinna"));
    app.setOrganizationName(QStringLiteral("pinna"));
    app.setDesktopFileName(QStringLiteral("dev.pinna.Pinna"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    const bool popup = app.arguments().contains(QStringLiteral("--popup"));

    Instance instance;
    // ekran görüntüsü alınırken açık olan pencereye karışma
    if (!popup && qEnvironmentVariable("PINNA_SHOT").isEmpty()) {
        auto bus = QDBusConnection::sessionBus();
        if (!bus.registerService(QStringLiteral("dev.pinna.App"))) {
            bus.call(QDBusMessage::createMethodCall(QStringLiteral("dev.pinna.App"), QStringLiteral("/"),
                                                    QStringLiteral("dev.pinna.App1"), QStringLiteral("Activate")));
            return 0;
        }
        bus.registerObject(QStringLiteral("/"), &instance, QDBusConnection::ExportScriptableSlots);
    }

    int id = QFontDatabase::addApplicationFont(QStringLiteral(":/qt/qml/Pinna/fonts/InstrumentSans.ttf"));
    if (id >= 0) {
        QFont f(QFontDatabase::applicationFontFamilies(id).value(0));
        f.setPixelSize(14);
        f.setHintingPreference(QFont::PreferNoHinting);
        app.setFont(f);
    }

    QQmlApplicationEngine engine;
    instance.engine = &engine;
    engine.rootContext()->setContextProperty(QStringLiteral("pinnaTheme"), qEnvironmentVariable("PINNA_THEME"));
    engine.rootContext()->setContextProperty(QStringLiteral("pinnaPage"), qEnvironmentVariable("PINNA_PAGE"));
    engine.rootContext()->setContextProperty(QStringLiteral("pinnaReduceMotion"), reduceMotion());
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    if (int h = qEnvironmentVariableIntValue("PINNA_SHOT_HEIGHT"))
        engine.setInitialProperties({{QStringLiteral("height"), h}});
    engine.loadFromModule("Pinna", popup ? "Popup" : "Main");

    // README görselleri için: PINNA_SHOT=dosya.png ile pencereyi kaydedip çık
    const QString shot = qEnvironmentVariable("PINNA_SHOT");
    if (!shot.isEmpty() && !engine.rootObjects().isEmpty()) {
        auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QTimer::singleShot(qEnvironmentVariableIntValue("PINNA_SHOT_DELAY") ?: 2500, w, [w, shot] {
            w->grabWindow().save(shot);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}

#include "main.moc"
