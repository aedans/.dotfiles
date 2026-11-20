// Workspace themes as Qt palettes, from each theme's window colors (see
// ../themes.nix), and the roles they set.
#pragma once
#include <QPalette>
#include <QString>
#include <optional>

// The theme's palette; none for no theme ("") or one the plugin doesn't know.
std::optional<QPalette> themePalette(const QString &theme);
// The theme roles of `from` faded toward `to`'s by t (0 to 1), over `to`.
QPalette mixPalettes(const QPalette &from, const QPalette &to, qreal t);
// The palette without the theme roles it sets, so a widget wearing it inherits
// them; none if it sets none.
std::optional<QPalette> withoutThemeRoles(const QPalette &palette);
