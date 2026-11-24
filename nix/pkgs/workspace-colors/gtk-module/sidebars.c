// A window wears "ws-sidebar" while it shows a sidebar beside its content: a
// mapped .sidebar-pane, which libadwaita's split views give their sidebar
// unless it's collapsed over the content. The stylesheets clear such windows'
// background behind the sidebar, for the shell to blur (Blur my Shell's
// application blur), and paint the content over it. Panes come and go as
// they're mapped and unmapped, and as split views collapse, so each change
// rechecks the window once it's idle.
//
// !!! On GNOME 51 (GTK 4.24) this is probably unnecessary: the stylesheets can
// blur the sidebar itself with backdrop-filter; see nix/de/gnome.nix. !!!
#define G_LOG_DOMAIN "workspace-theme"
#include "sidebars.h"
#include "toolkit.h"

#define SIDEBAR_CLASS "ws-sidebar"
#define PANE_CLASS "sidebar-pane"
#define PENDING_KEY "workspace-theme-sidebar-pending"
#define WATCHED_KEY "workspace-theme-sidebar-watched"

static gboolean is_split_view(GtkWidget *widget)
{
    const char *type = G_OBJECT_TYPE_NAME(widget);
    return g_strcmp0(type, "AdwOverlaySplitView") == 0 ||
           g_strcmp0(type, "AdwNavigationSplitView") == 0;
}

static gboolean shows_sidebar(GtkWidget *widget)
{
    if (!gtk_widget_get_mapped(widget))
        return FALSE;
    if (gtk_widget_has_css_class(widget, PANE_CLASS))
        return TRUE;
    for (GtkWidget *c = gtk_widget_get_first_child(widget); c; c = gtk_widget_get_next_sibling(c)) {
        if (shows_sidebar(c))
            return TRUE;
    }
    return FALSE;
}

static gboolean update(gpointer data)
{
    GtkWidget *window = data;
    g_object_set_data(G_OBJECT(window), PENDING_KEY, NULL);
    gboolean sidebar = shows_sidebar(window);
    if (sidebar != gtk_widget_has_css_class(window, SIDEBAR_CLASS)) {
        (sidebar ? widget_add_class : widget_remove_class)(window, SIDEBAR_CLASS);
        g_debug("%s: %s sidebar", G_OBJECT_TYPE_NAME(window), sidebar ? "shows" : "no longer shows");
    }
    g_object_unref(window);
    return G_SOURCE_REMOVE;
}

static void queue_update(GtkWidget *widget)
{
    GtkRoot *root = gtk_widget_get_root(widget);
    if (!GTK_IS_WINDOW(root) || g_object_get_data(G_OBJECT(root), PENDING_KEY))
        return;
    g_object_set_data(G_OBJECT(root), PENDING_KEY, GINT_TO_POINTER(1));
    g_idle_add(update, g_object_ref(root));
}

static void on_collapsed(GObject *split_view, GParamSpec *pspec, gpointer data)
{
    queue_update(GTK_WIDGET(split_view));
}

static gboolean on_map_change(GSignalInvocationHint *hint, guint n_params, const GValue *params,
                              gpointer data)
{
    GtkWidget *widget = g_value_get_object(&params[0]);
    if (is_split_view(widget)) {
        if (!g_object_get_data(G_OBJECT(widget), WATCHED_KEY)) {
            g_object_set_data(G_OBJECT(widget), WATCHED_KEY, GINT_TO_POINTER(1));
            g_signal_connect(widget, "notify::collapsed", G_CALLBACK(on_collapsed), NULL);
        }
        queue_update(widget);
    } else if (gtk_widget_has_css_class(widget, PANE_CLASS)) {
        queue_update(widget);
    }
    return TRUE;
}

void sidebars_setup(void)
{
    g_type_class_ref(GTK_TYPE_WIDGET);
    g_signal_add_emission_hook(g_signal_lookup("map", GTK_TYPE_WIDGET), 0, on_map_change, NULL, NULL);
    g_signal_add_emission_hook(g_signal_lookup("unmap", GTK_TYPE_WIDGET), 0, on_map_change, NULL, NULL);
}
