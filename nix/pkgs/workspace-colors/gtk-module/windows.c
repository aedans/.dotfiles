// A theme is a "ws-<theme>" class on a toplevel window, plus "ws-themed" while
// it has one. A theme change on an already themed window also adds
// "ws-animating" until the CSS transitions finish, so the stylesheets can
// enable color transitions only around theme changes. Windows that belong to
// another (dialogs, and in GTK 3 menus) take its theme as they're shown, and
// follow it when it changes.
#define G_LOG_DOMAIN "workspace-theme"
#include "windows.h"
#include "terminal.h"
#include "toolkit.h"

#define THEME_KEY "workspace-theme"
#define GENERATION_KEY "workspace-theme-generation"
#define ANIMATING_CLASS "ws-animating"
#define THEMED_CLASS "ws-themed"
// Longer than the stylesheets' transitions, so they finish before
// ws-animating is removed.
#define ANIMATING_MS 450

typedef struct {
    GtkWidget *window;
    guint generation;
} AnimationEnd;

static gboolean end_animation(gpointer data)
{
    AnimationEnd *end = data;
    guint current = GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(end->window), GENERATION_KEY));
    if (current == end->generation)
        widget_remove_class(end->window, ANIMATING_CLASS);
    g_object_unref(end->window);
    g_free(end);
    return G_SOURCE_REMOVE;
}

static void start_animation(GtkWidget *widget)
{
    guint generation = GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(widget), GENERATION_KEY)) + 1;
    g_object_set_data(G_OBJECT(widget), GENERATION_KEY, GUINT_TO_POINTER(generation));
    widget_add_class(widget, ANIMATING_CLASS);
    AnimationEnd *end = g_new(AnimationEnd, 1);
    end->window = g_object_ref(widget);
    end->generation = generation;
    g_timeout_add(ANIMATING_MS, end_animation, end);
}

void window_set_theme(GtkWindow *window, const char *theme)
{
    GtkWidget *widget = GTK_WIDGET(window);
    const char *old = g_object_get_data(G_OBJECT(window), THEME_KEY);
    if (g_strcmp0(old ? old : "", theme) == 0)
        return;

    gboolean animate = old != NULL && theme[0] != '\0';
    if (old) {
        g_autofree char *old_class = g_strconcat("ws-", old, NULL);
        widget_remove_class(widget, old_class);
    }
    if (animate)
        start_animation(widget);
    if (theme[0] != '\0') {
        g_autofree char *new_class = g_strconcat("ws-", theme, NULL);
        widget_add_class(widget, new_class);
        widget_add_class(widget, THEMED_CLASS);
    } else {
        widget_remove_class(widget, THEMED_CLASS);
    }
    g_debug("%s: %s -> %s%s", G_OBJECT_TYPE_NAME(window), old ? old : "(none)",
            theme[0] ? theme : "(none)", animate ? " (animated)" : "");
    g_object_set_data_full(G_OBJECT(window), THEME_KEY,
                           theme[0] ? g_strdup(theme) : NULL, g_free);
    terminal_apply(widget, theme, animate);

    GList *toplevels = gtk_window_list_toplevels();
    for (GList *l = toplevels; l; l = l->next) {
        if (window_parent(l->data) == window)
            window_set_theme(l->data, theme);
    }
    g_list_free(toplevels);
}

// The theme of the nearest window up the chain of owners that has one.
static const char *inherited_theme(GtkWindow *window)
{
    for (GtkWindow *w = window_parent(window); w; w = window_parent(w)) {
        const char *theme = g_object_get_data(G_OBJECT(w), THEME_KEY);
        if (theme)
            return theme;
    }
    return NULL;
}

static gboolean on_map(GSignalInvocationHint *hint, guint n_params, const GValue *params,
                       gpointer data)
{
    GObject *object = g_value_get_object(&params[0]);
    if (!GTK_IS_WINDOW(object) || g_object_get_data(object, THEME_KEY))
        return TRUE;
    const char *theme = inherited_theme(GTK_WINDOW(object));
    if (theme)
        window_set_theme(GTK_WINDOW(object), theme);
    return TRUE;
}

void windows_setup(void)
{
    // Signals exist once their class does, which may be before any widget.
    g_type_class_ref(GTK_TYPE_WIDGET);
    g_signal_add_emission_hook(g_signal_lookup("map", GTK_TYPE_WIDGET), 0, on_map, NULL, NULL);
}
