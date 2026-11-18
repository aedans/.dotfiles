// The few calls that differ between GTK 3 and GTK 4. The module is compiled
// once per toolkit; MODULE_GTK3 selects GTK 3.
#pragma once
#include <gtk/gtk.h>

static inline void widget_add_class(GtkWidget *widget, const char *name)
{
#ifdef MODULE_GTK3
    gtk_style_context_add_class(gtk_widget_get_style_context(widget), name);
#else
    gtk_widget_add_css_class(widget, name);
#endif
}

static inline void widget_remove_class(GtkWidget *widget, const char *name)
{
#ifdef MODULE_GTK3
    gtk_style_context_remove_class(gtk_widget_get_style_context(widget), name);
#else
    gtk_widget_remove_css_class(widget, name);
#endif
}

static inline void add_css_provider(const char *path, guint priority)
{
    GtkCssProvider *css = gtk_css_provider_new();
#ifdef MODULE_GTK3
    gtk_css_provider_load_from_path(css, path, NULL);
    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
                                              GTK_STYLE_PROVIDER(css), priority);
#else
    gtk_css_provider_load_from_path(css, path);
    gtk_style_context_add_provider_for_display(gdk_display_get_default(),
                                               GTK_STYLE_PROVIDER(css), priority);
#endif
    g_object_unref(css);
}

static inline void add_css_provider_from_string(const char *css, guint priority)
{
    GtkCssProvider *provider = gtk_css_provider_new();
#ifdef MODULE_GTK3
    gtk_css_provider_load_from_data(provider, css, -1, NULL);
    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
                                              GTK_STYLE_PROVIDER(provider), priority);
#else
    gtk_css_provider_load_from_string(provider, css);
    gtk_style_context_add_provider_for_display(gdk_display_get_default(),
                                               GTK_STYLE_PROVIDER(provider), priority);
#endif
    g_object_unref(provider);
}

static inline GtkWidget *widget_toplevel(GtkWidget *widget)
{
#ifdef MODULE_GTK3
    return gtk_widget_get_toplevel(widget);
#else
    return GTK_WIDGET(gtk_widget_get_root(widget));
#endif
}

#ifdef MODULE_GTK3
static void collect_child(GtkWidget *child, gpointer list)
{
    *(GSList **)list = g_slist_prepend(*(GSList **)list, child);
}
#endif

// The widget's children; free the list, not its widgets.
static inline GSList *widget_children(GtkWidget *widget)
{
    GSList *children = NULL;
#ifdef MODULE_GTK3
    if (GTK_IS_CONTAINER(widget))
        gtk_container_forall(GTK_CONTAINER(widget), collect_child, &children);
#else
    for (GtkWidget *c = gtk_widget_get_first_child(widget); c; c = gtk_widget_get_next_sibling(c))
        children = g_slist_prepend(children, c);
#endif
    return children;
}

// The window this one belongs to: its transient parent or, for a GTK 3 menu's
// window, the window of the widget the menu is attached to.
static inline GtkWindow *window_parent(GtkWindow *window)
{
    GtkWindow *parent = gtk_window_get_transient_for(window);
#ifdef MODULE_GTK3
    GtkWidget *child = gtk_bin_get_child(GTK_BIN(window));
    if (!parent && child && GTK_IS_MENU(child)) {
        GtkWidget *attached = gtk_menu_get_attach_widget(GTK_MENU(child));
        GtkWidget *toplevel = attached ? gtk_widget_get_toplevel(attached) : NULL;
        if (toplevel && GTK_IS_WINDOW(toplevel))
            parent = GTK_WINDOW(toplevel);
    }
#endif
    return parent;
}
