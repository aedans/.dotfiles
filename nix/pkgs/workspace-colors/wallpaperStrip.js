import Clutter from 'gi://Clutter';
import GDesktopEnums from 'gi://GDesktopEnums';
import Meta from 'gi://Meta';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {WORKSPACE_SPACING} from 'resource:///org/gnome/shell/ui/workspaceAnimation.js';

import {backgroundOf} from './backgrounds.js';
import {schemeAt} from './schemes.js';
import {watchWorkspacePosition} from './position.js';

// A monitor's workspace wallpapers, blurred and darkened when built (see
// default.nix), sliding past as the workspaces do, for the top bar and dock to
// show through them in place of a live blur of what's behind them (see
// panelBackdrop.js, dockBackdrop.js). Blur my Shell's live blur shows what's
// behind them as it changes, so the overview opening, or a window closing,
// swaps it within a couple of frames, and it takes a few more to settle, each
// a jolt beside their own fades; it also blurs every frame anything behind
// them moves. This shows no windows, so they're solid while one is behind them
// (see windowCover.js, chrome.js).
//
// The strip's actor is clipped to where it's placed, showing the part of each
// wallpaper there as if over the whole monitor; it takes no room in its
// parent's layout. Between workspaces is the switch animation's own gap color.

// Each workspace shown, as [index, offset], its offset from the monitor in
// workspace widths (heights, laid out vertically). A switch straight to a
// workspace further away (e.g. from the keyboard) slides it in beside the one
// it leaves, as the shell does, the position passing through those between
// while shown: jump, {from, to}.
function placements(position, jump) {
    if (jump) {
        const t = (position - jump.from) / (jump.to - jump.from);
        const direction = Math.sign(jump.to - jump.from);
        return [[jump.from, -t * direction], [jump.to, (1 - t) * direction]];
    }
    const index = Math.floor(position);
    return [[index, index - position], [index + 1, index + 1 - position]];
}

const between = (value, a, b) => (value - a) * (value - b) <= 0;

// monitorIndex: which monitor's wallpapers, as it changes. Returns {actor,
// setOrigin, destroy}: setOrigin(x, y) is where the actor is on the stage, as
// it moves.
export function createWallpaperStrip(schemes, monitorIndex) {
    const {layoutManager} = Main;
    const workspaces = global.workspace_manager;
    const actor = new St.Widget({
        style_class: 'workspace-animation',
        clip_to_allocation: true,
        width: 0,
        height: 0,
    });

    // A background per scheme, loading from the start so that none waits for
    // its image when first shown, and an actor showing it per workspace.
    let monitor = null;
    let backgrounds = [];
    const wallpapers = new Map();
    const build = () => {
        wallpapers.forEach(wallpaper => wallpaper.destroy());
        wallpapers.clear();
        monitor = layoutManager.monitors[monitorIndex()] ?? null;
        backgrounds = schemes.map(scheme => {
            const {file, color} = backgroundOf(scheme, monitor, 'blurred');
            const background = new Meta.Background({meta_display: global.display});
            background.set_color(color);
            if (file)
                background.set_file(file, GDesktopEnums.BackgroundStyle.ZOOM);
            return background;
        });
    };
    const wallpaperFor = index => {
        if (!wallpapers.has(index)) {
            const wallpaper = new Meta.BackgroundActor({
                meta_display: global.display,
                monitor: monitor.index,
                width: monitor.width,
                height: monitor.height,
            });
            wallpaper.content.background = backgrounds[schemes.indexOf(schemeAt(schemes, index))];
            actor.add_child(wallpaper);
            wallpapers.set(index, wallpaper);
        }
        return wallpapers.get(index);
    };

    // Placed by translation, which moves them without a relayout, so that the
    // origin can follow the actor as it's painted.
    let origin = [0, 0];
    let position = workspaces.get_active_workspace_index();
    let jump = null;
    const place = () => {
        if (!monitor)
            return;
        const vertical = workspaces.layout_rows === -1;
        const rtl = Clutter.get_default_text_direction() === Clutter.TextDirection.RTL;
        const spacing = WORKSPACE_SPACING * St.ThemeContext.get_for_stage(global.stage).scale_factor;
        const distance = (vertical ? monitor.height : monitor.width) + spacing;
        const shown = new Map(placements(position, jump).filter(([index, offset]) =>
            index >= 0 && index < workspaces.n_workspaces && Math.abs(offset) < 1));
        wallpapers.forEach((wallpaper, index) => {
            wallpaper.visible = shown.has(index);
        });
        shown.forEach((offset, index) => {
            const wallpaper = wallpaperFor(index);
            const along = Math.round(offset * distance) * (rtl && !vertical ? -1 : 1);
            wallpaper.set_translation(
                monitor.x - origin[0] + (vertical ? 0 : along),
                monitor.y - origin[1] + (vertical ? along : 0),
                0);
            wallpaper.show();
        });
    };

    build();

    const owner = {};
    // A switch activates the workspace it heads to before the position moves.
    workspaces.connectObject('active-workspace-changed', () => {
        const from = Math.round(position);
        const to = workspaces.get_active_workspace_index();
        jump = Math.abs(position - from) < 1e-6 && Math.abs(to - from) > 1 ? {from, to} : null;
    }, owner);
    const stopWatchingPosition = watchWorkspacePosition({
        onMove: p => {
            position = p;
            if (jump && (!between(position, jump.from, jump.to) || Math.abs(position - jump.to) < 1e-6))
                jump = null;
            place();
        },
    });
    layoutManager.connectObject('monitors-changed', () => {
        build();
        place();
    }, owner);

    return {
        actor,
        setOrigin: (x, y) => {
            if (x !== origin[0] || y !== origin[1]) {
                origin = [x, y];
                place();
            }
        },
        destroy: () => {
            stopWatchingPosition();
            [workspaces, layoutManager].forEach(o => o.disconnectObject(owner));
            actor.destroy();
            backgrounds = [];
        },
    };
}
