// Themes of top-level windows: each wears its theme's palette, and windows
// that belong to another (dialogs, menus) follow it.
#pragma once
#include <QString>

// Starts following new windows; call once the QApplication exists.
void windowsSetup(void);
// Gives the windows the shell sees with the title a theme ("" for none), and
// passes it on to the windows that belong to them. Returns whether any has it.
bool setTitledTheme(const QString &title, const QString &theme);
// The theme ("" for none) windows take as they're shown when no window they
// belong to has one, until the shell names them: the theme of the process's
// focused window, so new windows are themed from their first frame.
void windowsSetProcessTheme(const QString &theme);
