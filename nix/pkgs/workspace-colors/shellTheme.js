import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {WINDOW_ANIMATION_TIME} from 'resource:///org/gnome/shell/ui/workspaceAnimation.js';

import {watchWorkspacePosition} from './position.js';
import {schemeAt} from './schemes.js';

// The shell's own surfaces (menus, quick settings, notifications, overview)
// take their workspace's theme from a ws-<theme> class on the actor holding
// all of them: stylesheet.css gives each class its theme's tint and accent,
// which St applies to every color below it (see patches/st-tint.patch). The
// class changes as the position heads for a workspace, and the change
// crossfades for the slide's length while ws-animating is set.

const ANIMATING_CLASS = 'ws-animating';

const classOf = theme => `ws-${theme}`;

export function enableShellTheme(schemes) {
    const themes = new Set(schemes.map(s => s.theme).filter(theme => theme !== undefined));
    if (!themes.size)
        return () => {};

    // Each class change restyles the whole shell, so a state is set at once.
    const ours = new Set([ANIMATING_CLASS, ...[...themes].map(classOf)]);
    let current = null;
    let animating = 0;
    const show = () => {
        const others = (Main.uiGroup.get_style_class_name() ?? '').split(/\s+/)
            .filter(name => name && !ours.has(name));
        const names = [...others, ...animating ? [ANIMATING_CLASS] : [], ...current ? [classOf(current)] : []];
        Main.uiGroup.set_style_class_name(names.join(' ') || null);
    };
    const stopAnimating = () => {
        if (animating)
            GLib.source_remove(animating);
        animating = 0;
    };
    // The theme switches as the workspaces start sliding and crossfades for as
    // long as the slide takes; the animating class is dropped once it's done.
    const apply = (theme, animate) => {
        if (theme === current)
            return;
        stopAnimating();
        if (animate) {
            animating = GLib.timeout_add(GLib.PRIORITY_DEFAULT, WINDOW_ANIMATION_TIME * 2, () => {
                animating = 0;
                show();
                return GLib.SOURCE_REMOVE;
            });
        }
        current = theme;
        show();
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
        stopAnimating();
        apply(null, false);
    };
}
