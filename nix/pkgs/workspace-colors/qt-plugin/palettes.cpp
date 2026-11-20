// Each theme's palette maps its window colors onto Qt's roles: the window,
// views (Base), raised surfaces (tooltips), buttons, and the bevel shades
// styles draw edges with, stepping from the border up to the hover color.
// Disabled widgets fade their text and accents halfway into the window.
#include "palettes.h"

#include <QColor>
#include <QFile>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>

// THEMES_JSON: { <theme>: { window, view, ... } }, each theme's ui colors.

static const QPalette::ColorGroup GROUPS[] = {QPalette::Active, QPalette::Inactive,
                                              QPalette::Disabled};
// The roles themes set.
static const QPalette::ColorRole THEME_ROLES[] = {
    QPalette::Window, QPalette::WindowText, QPalette::Base, QPalette::AlternateBase,
    QPalette::ToolTipBase, QPalette::ToolTipText, QPalette::PlaceholderText, QPalette::Text,
    QPalette::Button, QPalette::ButtonText, QPalette::BrightText, QPalette::Light,
    QPalette::Midlight, QPalette::Mid, QPalette::Dark, QPalette::Shadow, QPalette::Highlight,
    QPalette::HighlightedText, QPalette::Link, QPalette::LinkVisited,
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
    QPalette::Accent,
#endif
};

static QColor mix(const QColor &from, const QColor &to, qreal t)
{
    return QColor::fromRgbF(from.redF() + (to.redF() - from.redF()) * t,
                            from.greenF() + (to.greenF() - from.greenF()) * t,
                            from.blueF() + (to.blueF() - from.blueF()) * t,
                            from.alphaF() + (to.alphaF() - from.alphaF()) * t);
}

static bool isThemeRole(QPalette::ColorRole role)
{
    for (QPalette::ColorRole themeRole : THEME_ROLES) {
        if (themeRole == role)
            return true;
    }
    return false;
}

static QPalette paletteOf(const QJsonObject &ui)
{
    auto color = [&ui](const char *key) { return QColor(ui.value(QLatin1String(key)).toString()); };
    const QColor window = color("window"), view = color("view"), raised = color("raised"),
                 sidebar = color("sidebar"), border = color("border"), button = color("button"),
                 hover = color("hover"), text = color("text"), accent = color("accent"),
                 accentText = color("accentText"), accentForeground = color("accentForeground");

    QPalette palette;
    for (QPalette::ColorGroup group : GROUPS) {
        const qreal dim = group == QPalette::Disabled ? 0.5 : 0;
        const QColor foreground = mix(text, window, dim);
        palette.setColor(group, QPalette::Window, window);
        palette.setColor(group, QPalette::WindowText, foreground);
        palette.setColor(group, QPalette::Base, view);
        palette.setColor(group, QPalette::AlternateBase, sidebar);
        palette.setColor(group, QPalette::ToolTipBase, raised);
        palette.setColor(group, QPalette::ToolTipText, text);
        palette.setColor(group, QPalette::PlaceholderText, mix(text, view, 0.5));
        palette.setColor(group, QPalette::Text, foreground);
        palette.setColor(group, QPalette::Button, button);
        palette.setColor(group, QPalette::ButtonText, foreground);
        palette.setColor(group, QPalette::BrightText, foreground);
        palette.setColor(group, QPalette::Light, hover);
        palette.setColor(group, QPalette::Midlight, mix(button, hover, 0.5));
        palette.setColor(group, QPalette::Mid, mix(border, button, 0.5));
        palette.setColor(group, QPalette::Dark, border);
        palette.setColor(group, QPalette::Shadow, border);
        palette.setColor(group, QPalette::Highlight, mix(accent, window, dim));
        palette.setColor(group, QPalette::HighlightedText, mix(accentForeground, window, dim));
        palette.setColor(group, QPalette::Link, mix(accentText, window, dim));
        palette.setColor(group, QPalette::LinkVisited, mix(accentText, window, dim));
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
        palette.setColor(group, QPalette::Accent, mix(accent, window, dim));
#endif
    }
    return palette;
}

static QHash<QString, QPalette> readPalettes(void)
{
    QHash<QString, QPalette> palettes;
    QFile file(QStringLiteral(THEMES_JSON));
    if (!file.open(QIODevice::ReadOnly))
        return palettes;
    const QJsonObject themes = QJsonDocument::fromJson(file.readAll()).object();
    for (auto theme = themes.begin(); theme != themes.end(); ++theme)
        palettes.insert(theme.key(), paletteOf(theme.value().toObject()));
    return palettes;
}

std::optional<QPalette> themePalette(const QString &theme)
{
    static const QHash<QString, QPalette> palettes = readPalettes();
    const auto palette = palettes.constFind(theme);
    if (palette == palettes.cend())
        return std::nullopt;
    return *palette;
}

QPalette mixPalettes(const QPalette &from, const QPalette &to, qreal t)
{
    QPalette mixed = to;
    for (QPalette::ColorGroup group : GROUPS) {
        for (QPalette::ColorRole role : THEME_ROLES)
            mixed.setColor(group, role, mix(from.color(group, role), to.color(group, role), t));
    }
    return mixed;
}

std::optional<QPalette> withoutThemeRoles(const QPalette &palette)
{
    // A default palette sets nothing; it takes the roles set here.
    QPalette kept;
    bool setsThemeRoles = false;
    for (QPalette::ColorGroup group : GROUPS) {
        for (int i = 0; i < QPalette::NColorRoles; i++) {
            const auto role = static_cast<QPalette::ColorRole>(i);
            if (role == QPalette::NoRole || !palette.isBrushSet(group, role))
                continue;
            if (isThemeRole(role))
                setsThemeRoles = true;
            else
                kept.setBrush(group, role, palette.brush(group, role));
        }
    }
    if (!setsThemeRoles)
        return std::nullopt;
    return kept;
}
