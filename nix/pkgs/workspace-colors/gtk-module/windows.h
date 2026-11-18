// Themes of toplevel windows: each wears a "ws-<theme>" class, and windows
// that belong to another (dialogs, menus) follow it.
#pragma once
#include <gtk/gtk.h>

// Starts following new windows; call once GTK is initialized.
void windows_setup(void);
// Gives the window a theme ("" for none) and passes it on to the windows
// that belong to it. Changes after the first are animated.
void window_set_theme(GtkWindow *window, const char *theme);
