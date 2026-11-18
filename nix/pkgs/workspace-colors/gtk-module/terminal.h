// Terminal colors per theme, for windows holding VTE terminals.
#pragma once
#include <gtk/gtk.h>

// Reads the palettes; call once GTK is initialized. priority is the CSS
// provider priority for the terminals' backgrounds.
void terminal_setup(guint priority);
// Fades (or sets) every terminal in the window to the theme's palette.
void terminal_apply(GtkWidget *window, const char *theme, gboolean animate);
