// VTE takes its colors from the application, not CSS, so terminals are
// recolored directly: each one fades from the colors it was last given to the
// theme's palette, frame by frame. Palettes come from a key file with one
// group per theme (foreground, background and a 16-color palette list).
// Terminals without a palette for the theme keep their colors. VTE is looked
// up at runtime, so either toolkit's build works. Some applications (Ptyxis)
// have VTE leave its background to CSS, so each theme's terminal background is
// also given as a stylesheet, which crossfades with the rest of the window.
#define _GNU_SOURCE
#define G_LOG_DOMAIN "workspace-theme"
#include <dlfcn.h>
#include <math.h>

#include "terminal.h"
#include "toolkit.h"

#define PALETTE_SIZE 16
#define COLORS_KEY "workspace-theme-colors"
#define FADE_KEY "workspace-theme-fade"
#define THEME_KEY "workspace-theme"
// Matches the stylesheet's transitions.
#define FADE_US (250 * G_TIME_SPAN_MILLISECOND)

typedef struct {
    GdkRGBA foreground;
    GdkRGBA background;
    GdkRGBA palette[PALETTE_SIZE];
} Colors;

typedef struct {
    Colors from;
    Colors to;
    gint64 start;
    guint tick;
} Fade;

typedef GType (*GetTypeFn)(void);
typedef void (*SetColorsFn)(gpointer terminal, const GdkRGBA *foreground,
                            const GdkRGBA *background, const GdkRGBA *palette,
                            gsize palette_size);

static GHashTable *palettes;
static SetColorsFn set_colors;
static GType terminal_type;

static gboolean parse_colors(GKeyFile *file, const char *theme, Colors *colors)
{
    g_autofree char *foreground = g_key_file_get_string(file, theme, "foreground", NULL);
    g_autofree char *background = g_key_file_get_string(file, theme, "background", NULL);
    gsize length = 0;
    g_auto(GStrv) palette = g_key_file_get_string_list(file, theme, "palette", &length, NULL);
    if (!foreground || !background || length != PALETTE_SIZE ||
        !gdk_rgba_parse(&colors->foreground, foreground) ||
        !gdk_rgba_parse(&colors->background, background))
        return FALSE;
    for (gsize i = 0; i < PALETTE_SIZE; i++) {
        if (!gdk_rgba_parse(&colors->palette[i], palette[i]))
            return FALSE;
    }
    return TRUE;
}

static float ease_out(float t)
{
    return 1 - powf(1 - t, 3);
}

static GdkRGBA mix_rgba(const GdkRGBA *a, const GdkRGBA *b, float t)
{
    return (GdkRGBA){a->red + (b->red - a->red) * t, a->green + (b->green - a->green) * t,
                     a->blue + (b->blue - a->blue) * t, a->alpha + (b->alpha - a->alpha) * t};
}

static Colors mix(const Colors *a, const Colors *b, float t)
{
    Colors out = {mix_rgba(&a->foreground, &b->foreground, t),
                  mix_rgba(&a->background, &b->background, t)};
    for (int i = 0; i < PALETTE_SIZE; i++)
        out.palette[i] = mix_rgba(&a->palette[i], &b->palette[i], t);
    return out;
}

static void show(GtkWidget *terminal, const Colors *colors)
{
    Colors *shown = g_object_get_data(G_OBJECT(terminal), COLORS_KEY);
    if (!shown) {
        shown = g_new(Colors, 1);
        g_object_set_data_full(G_OBJECT(terminal), COLORS_KEY, shown, g_free);
    }
    *shown = *colors;
    set_colors(terminal, &colors->foreground, &colors->background, colors->palette, PALETTE_SIZE);
}

static gboolean fade_tick(GtkWidget *terminal, GdkFrameClock *clock, gpointer data)
{
    Fade *fade = g_object_get_data(G_OBJECT(terminal), FADE_KEY);
    gint64 now = gdk_frame_clock_get_frame_time(clock);
    if (!fade->start)
        fade->start = now;
    float t = MIN(1.0f, (float)(now - fade->start) / FADE_US);
    Colors colors = mix(&fade->from, &fade->to, ease_out(t));
    show(terminal, &colors);
    if (t < 1.0f)
        return G_SOURCE_CONTINUE;
    fade->tick = 0;
    return G_SOURCE_REMOVE;
}

static void stop_fade(GtkWidget *terminal)
{
    Fade *fade = g_object_get_data(G_OBJECT(terminal), FADE_KEY);
    if (fade && fade->tick) {
        gtk_widget_remove_tick_callback(terminal, fade->tick);
        fade->tick = 0;
    }
}

static void recolor(GtkWidget *terminal, const Colors *target, gboolean animate)
{
    stop_fade(terminal);
    const Colors *shown = g_object_get_data(G_OBJECT(terminal), COLORS_KEY);
    if (!animate || !shown || !gtk_widget_get_mapped(terminal)) {
        show(terminal, target);
        return;
    }
    Fade *fade = g_object_get_data(G_OBJECT(terminal), FADE_KEY);
    if (!fade) {
        fade = g_new0(Fade, 1);
        g_object_set_data_full(G_OBJECT(terminal), FADE_KEY, fade, g_free);
    }
    fade->from = *shown;
    fade->to = *target;
    fade->start = 0;
    fade->tick = gtk_widget_add_tick_callback(terminal, fade_tick, NULL, NULL);
}

static void recolor_descendants(GtkWidget *widget, const Colors *target, gboolean animate)
{
    if (G_TYPE_CHECK_INSTANCE_TYPE(widget, terminal_type)) {
        recolor(widget, target, animate);
        return;
    }
    GSList *children = widget_children(widget);
    for (GSList *l = children; l; l = l->next)
        recolor_descendants(l->data, target, animate);
    g_slist_free(children);
}

void terminal_apply(GtkWidget *window, const char *theme, gboolean animate)
{
    const Colors *target = palettes ? g_hash_table_lookup(palettes, theme) : NULL;
    if (target && terminal_type)
        recolor_descendants(window, target, animate);
}

// New terminals (tabs, splits) take their window's palette as they appear,
// after the application has given them its own colors.
static gboolean on_map(GSignalInvocationHint *hint, guint n_params, const GValue *params,
                       gpointer data)
{
    GtkWidget *widget = g_value_get_object(&params[0]);
    if (!G_TYPE_CHECK_INSTANCE_TYPE(widget, terminal_type) ||
        g_object_get_data(G_OBJECT(widget), COLORS_KEY))
        return TRUE;
    GtkWidget *toplevel = widget_toplevel(widget);
    const char *theme = toplevel ? g_object_get_data(G_OBJECT(toplevel), THEME_KEY) : NULL;
    const Colors *target = theme ? g_hash_table_lookup(palettes, theme) : NULL;
    if (target)
        show(widget, target);
    return TRUE;
}

static void add_backgrounds(guint priority)
{
    g_autoptr(GString) css = g_string_new(NULL);
    GHashTableIter iter;
    gpointer theme;
    gpointer colors;
    g_hash_table_iter_init(&iter, palettes);
    while (g_hash_table_iter_next(&iter, &theme, &colors)) {
        g_autofree char *background = gdk_rgba_to_string(&((Colors *)colors)->background);
        g_string_append_printf(css, ".ws-%s vte-terminal { background-color: %s; }\n",
                               (char *)theme, background);
    }
    add_css_provider_from_string(css->str, priority);
}

void terminal_setup(guint priority)
{
    // Registers the type even before the first terminal exists.
    GetTypeFn get_type = (GetTypeFn)dlsym(RTLD_DEFAULT, "vte_terminal_get_type");
    set_colors = (SetColorsFn)dlsym(RTLD_DEFAULT, "vte_terminal_set_colors");
    if (!get_type || !set_colors)
        return;
    terminal_type = get_type();

    g_autoptr(GKeyFile) file = g_key_file_new();
    g_autoptr(GError) error = NULL;
    if (!g_key_file_load_from_file(file, TERMINAL_PALETTES, G_KEY_FILE_NONE, &error)) {
        g_warning("Could not read %s: %s", TERMINAL_PALETTES, error->message);
        return;
    }
    palettes = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
    g_auto(GStrv) themes = g_key_file_get_groups(file, NULL);
    for (char **theme = themes; *theme; theme++) {
        Colors *colors = g_new(Colors, 1);
        if (parse_colors(file, *theme, colors))
            g_hash_table_insert(palettes, g_strdup(*theme), colors);
        else {
            g_warning("Bad terminal palette %s", *theme);
            g_free(colors);
        }
    }
    add_backgrounds(priority);
    g_type_class_ref(GTK_TYPE_WIDGET);
    g_signal_add_emission_hook(g_signal_lookup("map", GTK_TYPE_WIDGET), 0, on_map, NULL, NULL);
    g_debug("terminal palettes for %u themes", g_hash_table_size(palettes));
}
