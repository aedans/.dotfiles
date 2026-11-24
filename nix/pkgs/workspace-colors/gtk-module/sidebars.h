// Windows showing a libadwaita sidebar beside their content wear "ws-sidebar"
// (GTK 4 only).
#pragma once
#include <gtk/gtk.h>

// Starts following sidebars; call once GTK is initialized.
void sidebars_setup(void);
