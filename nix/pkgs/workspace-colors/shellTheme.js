import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {WINDOW_ANIMATION_TIME} from 'resource:///org/gnome/shell/ui/workspaceAnimation.js';

import {DOCK_STYLESHEET} from './dockStylesheet.js';
import {watchWorkspacePosition} from './position.js';
import {schemeAt} from './schemes.js';
import {ANIMATING_CLASS, scopedStylesheet} from './scopedCss.js';

// The shell's own surfaces (menus, quick settings, notifications, overview)
// take their workspace's theme from a stylesheet scoped under a ws-<theme>
// class on the actor holding all of them. The class changes as the position
// heads for a workspace, and the change crossfades for the slide's length.
//
// The stylesheet is generated from whatever the shell has loaded: its theme
// (a user theme included) and every extension's stylesheet, so their
// overrides keep winning. It is regenerated when that set changes: loading
// it restyles the whole shell, so not when an extension changes state without
// changing the set.
//
// St resolves a widget's style once per state (its classes and its
// ancestors') and keeps it until the stylesheets change, but resolving it
// against every theme's copy of the shell's stylesheet is slow enough that a
// workspace's first switch stutters. So once loaded, each state a switch can
// show is resolved ahead of time, one per idle, with animations inhibited so
// that nothing visibly transitions to it. That waits for the shell's startup
// animation, which it would stutter.

const classOf = theme => `ws-${theme}`;

function readText(file) {
    const [, bytes] = file.load_contents(null);
    return new TextDecoder().decode(bytes);
}

export function enableShellTheme(schemes, themes) {
    if (!schemes.some(s => s.theme !== undefined))
        return () => {};

    const context = St.ThemeContext.get_for_stage(global.stage);
    // The generated file, the theme it was loaded into and the stylesheets it
    // was generated from.
    let loaded = null;
    let generation = 0;

    // The theme switches as the workspaces start sliding and crossfades for as
    // long as the slide takes; the animating class is dropped once it's done.
    // Each class change restyles the whole shell, so a state is set at once.
    const ours = new Set([ANIMATING_CLASS, ...Object.keys(themes).map(classOf)]);
    const setState = (theme, animated) => {
        const others = (Main.uiGroup.get_style_class_name() ?? '').split(/\s+/)
            .filter(name => name && !ours.has(name));
        const names = [...others, ...animated ? [ANIMATING_CLASS] : [], ...theme ? [classOf(theme)] : []];
        Main.uiGroup.set_style_class_name(names.join(' ') || null);
    };
    let current = null;
    let animating = 0;
    const show = () => setState(current, animating !== 0);
    const stopAnimating = () => {
        if (animating)
            GLib.source_remove(animating);
        animating = 0;
    };
    const apply = (theme, animate) => {
        if (theme === current)
            return;
        stopAnimating();
        if (animate) {
            animating = GLib.timeout_add(GLib.PRIORITY_DEFAULT, WINDOW_ANIMATION_TIME * 2, () => {
                animating = 0;
                show();
                scheduleResolving();
                return GLib.SOURCE_REMOVE;
            });
        }
        current = theme;
        show();
    };

    // The workspaces' themes, and the states of them not yet resolved. None
    // is resolved during a switch, which inhibiting animations would cut short.
    const used = new Set(schemes.map(s => s.theme).filter(theme => theme !== undefined));
    let unresolved = [];
    let resolving = 0;
    const scheduleResolving = () => {
        if (resolving || animating || Main.layoutManager._startingUp || !unresolved.length)
            return;
        resolving = GLib.idle_add(GLib.PRIORITY_LOW, () => {
            resolving = 0;
            if (animating)
                return GLib.SOURCE_REMOVE;
            const {theme, animated} = unresolved.shift();
            const settings = St.Settings.get();
            settings.inhibit_animations();
            setState(theme, animated);
            show();
            settings.uninhibit_animations();
            scheduleResolving();
            return GLib.SOURCE_REMOVE;
        });
    };

    const unload = () => {
        if (!loaded)
            return;
        const {theme, file} = loaded;
        // Cleared after: unloading emits the context's 'changed' synchronously.
        if (theme === context.get_theme())
            theme.unload_stylesheet(file);
        loaded = null;
        file.delete(null);
    };
    const regenerate = () => {
        const theme = context.get_theme();
        const sources = [
            theme.theme_stylesheet ?? theme.default_stylesheet,
            ...theme.get_custom_stylesheets(),
        ].filter(file => file && !(loaded && file.equal(loaded.file)));
        const key = sources.map(file => file.get_uri()).join('\n');
        if (loaded?.theme === theme && loaded.key === key)
            return;
        unload();
        // A fresh path each time: St caches stylesheets by file.
        const file = Gio.File.new_for_path(GLib.build_filenamev(
            [GLib.get_user_runtime_dir(), `workspace-colors-${generation++}.css`]));
        const css = scopedStylesheet([...sources.map(readText), DOCK_STYLESHEET], themes, WINDOW_ANIMATION_TIME);
        file.replace_contents(new TextEncoder().encode(css), null, false,
            Gio.FileCreateFlags.REPLACE_DESTINATION, null);
        // Set first: loading emits the context's 'changed' synchronously.
        loaded = {theme, file, key};
        theme.load_stylesheet(file);
        // Loading dropped every resolved style.
        unresolved = [...used].flatMap(theme => [{theme, animated: true}, {theme, animated: false}]);
        scheduleResolving();
    };

    // Other extensions load stylesheets as they enable; batch those changes.
    let pending = 0;
    const scheduleRegenerate = () => {
        if (!pending) {
            pending = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                pending = 0;
                regenerate();
                return GLib.SOURCE_REMOVE;
            });
        }
    };
    const owner = {};
    // A new theme (e.g. from user-theme) drops our stylesheet with the old
    // one. Changes to the theme we loaded into, our own included, are ignored.
    context.connectObject('changed', () => {
        if (context.get_theme() !== loaded?.theme)
            scheduleRegenerate();
    }, owner);
    Main.extensionManager.connectObject('extension-state-changed', scheduleRegenerate, owner);
    if (Main.layoutManager._startingUp)
        Main.layoutManager.connectObject('startup-complete', scheduleResolving, owner);
    regenerate();

    // The first heading is the workspace the shell starts on.
    let started = false;
    const stopWatching = watchWorkspacePosition({
        onHeading: index => {
            apply(schemeAt(schemes, index).theme ?? null, started);
            started = true;
        },
    });

    return () => {
        stopWatching();
        stopAnimating();
        if (resolving)
            GLib.source_remove(resolving);
        unresolved = [];
        apply(null, false);
        context.disconnectObject(owner);
        Main.extensionManager.disconnectObject(owner);
        Main.layoutManager.disconnectObject(owner);
        if (pending)
            GLib.source_remove(pending);
        unload();
    };
}
