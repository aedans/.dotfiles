// Gives each top-level window of a Qt Widgets process the theme the shell
// chooses for it, as the GTK module does for GTK's (see ../gtk-module). The
// shell can't tell Qt's windows apart but by title, so it names them by title
// (SetToplevelTheme), sent to the name org.hans.WorkspaceTheme.Qt<pid> each
// process running the plugin owns, along with the theme of the process's
// focused window (SetProcessTheme), which new windows wear until they're
// named. Qt loads it into every application as a generic plugin, from
// QT_QPA_GENERIC_PLUGINS, as it creates the application.
#include <QApplication>
#include <QDBusConnection>
#include <QDBusContext>
#include <QDBusError>
#include <QGenericPlugin>
#include <unistd.h>

#include "windows.h"

#define OBJECT_PATH "/org/hans/WorkspaceTheme"
#define BUS_NAME_PREFIX "org.hans.WorkspaceTheme.Qt"

// The exported object; its slots are the interface's methods.
class WorkspaceTheme : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.hans.WorkspaceTheme")

public Q_SLOTS:
    void SetToplevelTheme(const QString &title, const QString &theme)
    {
        if (!setTitledTheme(title, theme))
            sendErrorReply(QDBusError::InvalidArgs, QStringLiteral("No window %1").arg(title));
    }

    void SetProcessTheme(const QString &theme) { windowsSetProcessTheme(theme); }
};

class WorkspaceThemePlugin : public QGenericPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QGenericPluginFactoryInterface_iid FILE "metadata.json")

public:
    QObject *create(const QString &key, const QString &specification) override;
};

static void exportObject(QObject *object)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning("workspace-theme: no session bus");
        return;
    }
    if (!bus.registerObject(QStringLiteral(OBJECT_PATH), object, QDBusConnection::ExportAllSlots)) {
        qWarning("workspace-theme: could not export " OBJECT_PATH);
        return;
    }
    bus.registerService(QStringLiteral(BUS_NAME_PREFIX "%1").arg(getpid()));
}

// Qt keeps the object until the application quits. Processes without widgets
// get an object doing nothing.
QObject *WorkspaceThemePlugin::create(const QString &, const QString &)
{
    if (!qobject_cast<QApplication *>(QCoreApplication::instance()))
        return new QObject;
    auto *object = new WorkspaceTheme;
    windowsSetup();
    exportObject(object);
    return object;
}

#include "plugin.moc"
