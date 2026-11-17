import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {WINDOW_ANIMATION_TIME} from 'resource:///org/gnome/shell/ui/workspaceAnimation.js';

import {DOCK_STYLESHEET} from './chrome.js';
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
// overrides keep winning. It is regenerated when that set changes.

const classOf = theme => `ws-${theme}`;

function readText(file) {
    const [, bytes] = file.load_contents(null);
    return new TextDecoder().decode(bytes);
}

export function enableShellTheme(schemes, themes) {
    if (!schemes.some(s => s.theme !== undefined))
        return () => {};

    const context = St.ThemeContext.get_for_stage(global.stage);
    // The generated file and the theme it was loaded into.
    let loaded = null;
    let generation = 0;

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
        unload();
        const theme = context.get_theme();
        const sources = [
            theme.theme_stylesheet ?? theme.default_stylesheet,
            ...theme.get_custom_stylesheets(),
        ].filter(Boolean);
        // A fresh path each time: St caches stylesheets by file.
        const file = Gio.File.new_for_path(GLib.build_filenamev(
            [GLib.get_user_runtime_dir(), `workspace-colors-${generation++}.css`]));
        const css = scopedStylesheet([...sources.map(readText), DOCK_STYLESHEET], themes, WINDOW_ANIMATION_TIME);
        file.replace_contents(new TextEncoder().encode(css), null, false,
            Gio.FileCreateFlags.REPLACE_DESTINATION, null);
        // Set first: loading emits the context's 'changed' synchronously.
        loaded = {theme, file};
        theme.load_stylesheet(file);
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
    regenerate();

    // The theme switches as the workspaces start sliding and crossfades for as
    // long as the slide takes; the animating class is dropped once it's done.
    let current = null;
    let animating = 0;
    const stopAnimating = () => {
        if (animating)
            GLib.source_remove(animating);
        animating = 0;
        Main.uiGroup.remove_style_class_name(ANIMATING_CLASS);
    };
    const apply = (theme, animate) => {
        if (theme === current)
            return;
        stopAnimating();
        if (animate) {
            Main.uiGroup.add_style_class_name(ANIMATING_CLASS);
            animating = GLib.timeout_add(GLib.PRIORITY_DEFAULT, WINDOW_ANIMATION_TIME * 2, () => {
                animating = 0;
                stopAnimating();
                return GLib.SOURCE_REMOVE;
            });
        }
        if (current)
            Main.uiGroup.remove_style_class_name(classOf(current));
        if (theme)
            Main.uiGroup.add_style_class_name(classOf(theme));
        current = theme;
    };
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
        apply(null, false);
        stopAnimating();
        context.disconnectObject(owner);
        Main.extensionManager.disconnectObject(owner);
        if (pending)
            GLib.source_remove(pending);
        unload();
    };
}
