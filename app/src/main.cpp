#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

// İkinci kez açılınca yeni pencere yerine var olanı öne getirmek için.
class Instance : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "dev.earshot.App1")
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

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Earshot"));
    app.setOrganizationName(QStringLiteral("earshot"));
    app.setDesktopFileName(QStringLiteral("dev.earshot.Earshot"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    const bool popup = app.arguments().contains(QStringLiteral("--popup"));

    Instance instance;
    if (!popup) {
        auto bus = QDBusConnection::sessionBus();
        if (!bus.registerService(QStringLiteral("dev.earshot.App"))) {
            bus.call(QDBusMessage::createMethodCall(QStringLiteral("dev.earshot.App"), QStringLiteral("/"),
                                                    QStringLiteral("dev.earshot.App1"), QStringLiteral("Activate")));
            return 0;
        }
        bus.registerObject(QStringLiteral("/"), &instance, QDBusConnection::ExportScriptableSlots);
    }

    int id = QFontDatabase::addApplicationFont(QStringLiteral(":/qt/qml/Earshot/fonts/InstrumentSans.ttf"));
    if (id >= 0) {
        QFont f(QFontDatabase::applicationFontFamilies(id).value(0));
        f.setPixelSize(14);
        f.setHintingPreference(QFont::PreferNoHinting);
        app.setFont(f);
    }

    QQmlApplicationEngine engine;
    instance.engine = &engine;
    engine.rootContext()->setContextProperty(QStringLiteral("earshotTheme"), qEnvironmentVariable("EARSHOT_THEME"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    if (int h = qEnvironmentVariableIntValue("EARSHOT_SHOT_HEIGHT"))
        engine.setInitialProperties({{QStringLiteral("height"), h}});
    engine.loadFromModule("Earshot", popup ? "Popup" : "Main");

    // README görselleri için: EARSHOT_SHOT=dosya.png ile pencereyi kaydedip çık
    const QString shot = qEnvironmentVariable("EARSHOT_SHOT");
    if (!shot.isEmpty() && !engine.rootObjects().isEmpty()) {
        auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QTimer::singleShot(qEnvironmentVariableIntValue("EARSHOT_SHOT_DELAY") ?: 2500, w, [w, shot] {
            w->grabWindow().save(shot);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}

#include "main.moc"
