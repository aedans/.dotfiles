// A theme is its palette, set on a top-level window, which its widgets
// inherit. A theme change on an already themed window fades the palette, as
// long as the workspace slide and eased like it; any other change (a first
// theme, or none), and any change to a hidden window, applies at once. Widgets
// that set theme roles themselves (as some applications' styles do for menu
// bars and toolbars) give them up while their window is themed. A window without a theme wears its own palette
// again. Windows that belong to another (dialogs, menus, popups) take its
// theme as they're shown, and follow it when it changes; other windows take
// the process's theme.
#include "windows.h"
#include "palettes.h"

#include <QApplication>
#include <QChildEvent>
#include <QEasingCurve>
#include <QHash>
#include <QLoggingCategory>
#include <QPointer>
#include <QVariantAnimation>
#include <QWidget>
#include <QWindow>

// See ../stylesheets.nix: ease-out cubic.
#define FADE_MS 250
// A widget's own palette, kept while its window is themed.
#define OWN_PALETTE_PROPERTY "workspaceThemeOwnPalette"

struct WindowState {
    // "" for none.
    QString theme;
    // The window's own palette while it's themed, if it set one.
    std::optional<QPalette> own;
    QPointer<QVariantAnimation> fade;
};

// Sees windows as they're shown and widgets as they're polished.
struct WindowFilter : QObject {
    using QObject::QObject;
    bool eventFilter(QObject *object, QEvent *event) override;
};

Q_LOGGING_CATEGORY(themeLog, "workspace-theme")

static QHash<QWidget *, WindowState> states;
static QString processTheme;

static QString themeOf(QWidget *window)
{
    const auto state = states.constFind(window);
    return state == states.cend() ? QString() : state->theme;
}

// The window this one belongs to: the window of its parent widget.
static QWidget *owner(QWidget *window)
{
    QWidget *parent = window->parentWidget();
    return parent ? parent->window() : nullptr;
}

// The theme of the nearest window up the chain of owners that has one.
static QString inheritedTheme(QWidget *window)
{
    for (QWidget *w = owner(window); w; w = owner(w)) {
        const QString theme = themeOf(w);
        if (!theme.isEmpty())
            return theme;
    }
    return QString();
}

// Windows the shell names, rather than following another window.
static bool isNamed(QWidget *window)
{
    const Qt::WindowType type = window->windowType();
    return type == Qt::Window || type == Qt::Dialog;
}

// Whether the window system shows the window with the title: its own, or for
// an application with a display name, followed by that name, as Qt shows it.
static bool showsTitle(QWidget *window, const QString &title)
{
    const QString own = window->windowHandle()->title();
    const QString name = QGuiApplication::applicationDisplayName();
    if (own.isEmpty())
        return title == name || title == QCoreApplication::applicationName();
    return title == own || title == own + QString::fromUtf8(" — ") + name;
}

static void releaseThemeRoles(QWidget *widget)
{
    if (!widget->testAttribute(Qt::WA_SetPalette) || widget->property(OWN_PALETTE_PROPERTY).isValid())
        return;
    const QPalette own = widget->palette();
    const std::optional<QPalette> released = withoutThemeRoles(own);
    if (!released)
        return;
    widget->setProperty(OWN_PALETTE_PROPERTY, QVariant::fromValue(own));
    widget->setPalette(*released);
}

static void restoreThemeRoles(QWidget *widget)
{
    const QVariant own = widget->property(OWN_PALETTE_PROPERTY);
    if (!own.isValid())
        return;
    widget->setProperty(OWN_PALETTE_PROPERTY, QVariant());
    widget->setPalette(own.value<QPalette>());
}

// Applies f to the window's widgets, not those of the windows in it.
template <typename F> static void forEachWidget(QWidget *window, F f)
{
    for (QWidget *widget : window->findChildren<QWidget *>()) {
        if (!widget->isWindow() && widget->window() == window)
            f(widget);
    }
}

static void setPalette(QWidget *window, WindowState &state, const QPalette &palette, bool animate)
{
    if (state.fade)
        state.fade->stop();
    if (!animate) {
        window->setPalette(palette);
        return;
    }
    const QPalette from = window->palette();
    auto *fade = new QVariantAnimation(window);
    fade->setDuration(FADE_MS);
    fade->setEasingCurve(QEasingCurve::OutCubic);
    fade->setStartValue(0.0);
    fade->setEndValue(1.0);
    QObject::connect(fade, &QVariantAnimation::valueChanged, window,
                     [window, from, palette](const QVariant &t) {
                         window->setPalette(mixPalettes(from, palette, t.toReal()));
                     });
    QObject::connect(fade, &QVariantAnimation::finished, window,
                     [window, palette] { window->setPalette(palette); });
    state.fade = fade;
    fade->start(QAbstractAnimation::DeleteWhenStopped);
}

static void windowSetTheme(QWidget *window, const QString &requested)
{
    const std::optional<QPalette> palette = themePalette(requested);
    const QString theme = palette ? requested : QString();
    const QString old = themeOf(window);
    if (old == theme)
        return;

    if (!states.contains(window))
        QObject::connect(window, &QObject::destroyed, [window] { states.remove(window); });
    WindowState &state = states[window];
    const bool animate = !old.isEmpty() && palette && window->isVisible();
    if (old.isEmpty()) {
        state.own = window->testAttribute(Qt::WA_SetPalette) ? std::optional(window->palette())
                                                             : std::nullopt;
        forEachWidget(window, releaseThemeRoles);
    }
    if (palette) {
        setPalette(window, state, *palette, animate);
    } else {
        // A default palette sets nothing, so the window inherits again.
        setPalette(window, state, state.own.value_or(QPalette()), false);
        forEachWidget(window, restoreThemeRoles);
    }
    qCDebug(themeLog) << window->metaObject()->className() << window->windowTitle() << ":"
                 << (old.isEmpty() ? "(none)" : old) << "->" << (theme.isEmpty() ? "(none)" : theme)
                 << (animate ? "(animated)" : "");
    state.theme = theme;

    for (QWidget *w : QApplication::topLevelWidgets()) {
        if (w != window && owner(w) == window)
            windowSetTheme(w, theme);
    }
}

static void onShow(QWidget *window)
{
    if (!themeOf(window).isEmpty())
        return;
    QString theme = inheritedTheme(window);
    if (theme.isEmpty() && !owner(window) && isNamed(window))
        theme = processTheme;
    if (!theme.isEmpty())
        windowSetTheme(window, theme);
}

bool WindowFilter::eventFilter(QObject *object, QEvent *event)
{
    switch (event->type()) {
    case QEvent::Show:
        if (object->isWidgetType()) {
            auto *widget = static_cast<QWidget *>(object);
            if (widget->isWindow())
                onShow(widget);
        }
        break;
    case QEvent::ChildPolished: {
        QObject *child = static_cast<QChildEvent *>(event)->child();
        if (child->isWidgetType()) {
            auto *widget = static_cast<QWidget *>(child);
            if (!widget->isWindow() && !themeOf(widget->window()).isEmpty())
                releaseThemeRoles(widget);
        }
        break;
    }
    default:
        break;
    }
    return false;
}

bool setTitledTheme(const QString &title, const QString &theme)
{
    bool found = false;
    for (QWidget *window : QApplication::topLevelWidgets()) {
        if (isNamed(window) && window->windowHandle() && showsTitle(window, title)) {
            windowSetTheme(window, theme);
            found = true;
        }
    }
    if (!found) {
        QStringList titles;
        for (QWidget *window : QApplication::topLevelWidgets()) {
            if (isNamed(window) && window->windowHandle())
                titles << window->windowHandle()->title();
        }
        qCDebug(themeLog) << "no window titled" << title << "among" << titles;
    }
    return found;
}

void windowsSetProcessTheme(const QString &theme)
{
    processTheme = theme;
}

void windowsSetup(void)
{
    qApp->installEventFilter(new WindowFilter(qApp));
    qCDebug(themeLog) << "loaded into" << QCoreApplication::applicationName();
}
