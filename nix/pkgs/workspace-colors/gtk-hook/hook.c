// Gives each toplevel window of a GTK process the theme the shell chooses for
// it; the shell knows each window's workspace. Application windows are named
// by their GtkApplication object path (SetWindowTheme). Other windows the
// shell can see, such as file pickers shown by the desktop portal, have no
// such path, so they are named by title (SetToplevelTheme), sent to the name
// org.hans.WorkspaceTheme.P<pid> each hooked process owns. Windows that belong
// to another follow it (see windows.c).
#define G_LOG_DOMAIN "workspace-theme"
#include <unistd.h>

#include "terminal.h"
#include "toolkit.h"
#include "windows.h"

#define OBJECT_PATH "/org/hans/WorkspaceTheme"
#define BUS_NAME_PREFIX "org.hans.WorkspaceTheme.P"
// Above libadwaita's "* { transition: none; }" during its own style switches.
#define PROVIDER_PRIORITY 10001

static const char introspection_xml[] =
    "<node>"
    "  <interface name='org.hans.WorkspaceTheme'>"
    "    <method name='SetWindowTheme'>"
    "      <arg type='s' name='window_path' direction='in'/>"
    "      <arg type='s' name='theme' direction='in'/>"
    "    </method>"
    "    <method name='SetToplevelTheme'>"
    "      <arg type='s' name='title' direction='in'/>"
    "      <arg type='s' name='theme' direction='in'/>"
    "    </method>"
    "  </interface>"
    "</node>";

static GtkWindow *find_application_window(const char *window_path)
{
    GApplication *application = g_application_get_default();
    if (!GTK_IS_APPLICATION(application))
        return NULL;
    const char *app_path = g_application_get_dbus_object_path(application);
    for (GList *l = gtk_application_get_windows(GTK_APPLICATION(application)); l; l = l->next) {
        if (!GTK_IS_APPLICATION_WINDOW(l->data))
            continue;
        g_autofree char *path = g_strdup_printf(
            "%s/window/%u", app_path, gtk_application_window_get_id(l->data));
        if (g_strcmp0(path, window_path) == 0)
            return l->data;
    }
    return NULL;
}

// Returns whether any window has the title.
static gboolean set_titled_theme(const char *title, const char *theme)
{
    gboolean found = FALSE;
    GList *toplevels = gtk_window_list_toplevels();
    for (GList *l = toplevels; l; l = l->next) {
        if (g_strcmp0(gtk_window_get_title(l->data), title) == 0) {
            window_set_theme(l->data, theme);
            found = TRUE;
        }
    }
    g_list_free(toplevels);
    return found;
}

static void handle_method(GDBusConnection *connection, const char *sender,
                          const char *object_path, const char *interface_name,
                          const char *method_name, GVariant *parameters,
                          GDBusMethodInvocation *invocation, gpointer user_data)
{
    const char *name;
    const char *theme;
    g_variant_get(parameters, "(&s&s)", &name, &theme);

    gboolean found;
    if (g_strcmp0(method_name, "SetWindowTheme") == 0) {
        GtkWindow *window = find_application_window(name);
        if (window)
            window_set_theme(window, theme);
        found = window != NULL;
    } else {
        found = set_titled_theme(name, theme);
    }
    if (found)
        g_dbus_method_invocation_return_value(invocation, NULL);
    else
        g_dbus_method_invocation_return_error(invocation, G_DBUS_ERROR,
                                              G_DBUS_ERROR_INVALID_ARGS, "No window %s", name);
}

static const GDBusInterfaceVTable vtable = {.method_call = handle_method};

static void export_object(void)
{
    g_autoptr(GError) error = NULL;
    GDBusConnection *connection = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!connection) {
        g_warning("No session bus: %s", error->message);
        return;
    }
    g_autoptr(GDBusNodeInfo) node = g_dbus_node_info_new_for_xml(introspection_xml, NULL);
    if (!g_dbus_connection_register_object(connection, OBJECT_PATH, node->interfaces[0],
                                           &vtable, NULL, NULL, &error)) {
        g_warning("Could not export %s: %s", OBJECT_PATH, error->message);
        return;
    }
    g_autofree char *name = g_strdup_printf(BUS_NAME_PREFIX "%d", (int)getpid());
    g_bus_own_name_on_connection(connection, name, G_BUS_NAME_OWNER_FLAGS_NONE,
                                 NULL, NULL, NULL, NULL);
}

// Called once GTK is initialized: from GApplication's startup signal (whose
// class handlers, which initialize GTK, have run by then) or after gtk_init.
// Either may come first, or both.
G_MODULE_EXPORT void workspace_theme_attach(void)
{
    static gboolean attached;
    if (attached)
        return;
    attached = TRUE;
    add_css_provider(THEME_CSS, PROVIDER_PRIORITY);
    terminal_setup(PROVIDER_PRIORITY);
    windows_setup();
    export_object();
    GApplication *application = g_application_get_default();
    g_debug("attached to %s", application ? g_application_get_application_id(application)
                                          : g_get_prgname());
}
