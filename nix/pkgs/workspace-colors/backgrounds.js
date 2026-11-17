import Cogl from 'gi://Cogl';
import GDesktopEnums from 'gi://GDesktopEnums';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import {InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Background from 'resource:///org/gnome/shell/ui/background.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Workspace from 'resource:///org/gnome/shell/ui/workspace.js';
import * as WorkspaceAnimation from 'resource:///org/gnome/shell/ui/workspaceAnimation.js';

import {fieldOfAll} from './schemes.js';

// Backgrounds are not written to gsettings: a background settings change makes
// GNOME rebuild every background actor with a 1s crossfade, racing the copies
// the switch animation draws. Instead each workspace owns a Meta.Background,
// and background actors are pointed at one directly: the per-workspace copies
// drawn by the switch animation and the overview at their workspace's, every
// other actor at the active workspace's.

// The image, zoomed to fill its monitor, over the color, which shows until the
// image has loaded.
function workspaceBackground(color, image) {
    const [, cogl] = Cogl.Color.from_string(color);
    const background = new Meta.Background({meta_display: global.display});
    background.set_color(cogl);
    if (image)
        background.set_file(Gio.File.new_for_path(image), GDesktopEnums.BackgroundStyle.ZOOM);
    // BackgroundManager waits for 'loaded' on backgrounds that aren't.
    background.isLoaded = true;
    return background;
}

// The crop (see default.nix) whose shape is closest to the monitor's, so that
// zooming it to fill the monitor cuts off little more than the crop chose to.
function closestCrop(crops, monitor) {
    const mismatch = crop => Math.abs(Math.log(crop.aspect * monitor.height / monitor.width));
    return crops.reduce((best, crop) => mismatch(crop) < mismatch(best) ? crop : best);
}

function* descendants(actor) {
    for (const child of actor.get_children()) {
        yield child;
        yield* descendants(child);
    }
}

function pointAt(manager, background) {
    for (const actor of [manager.backgroundActor, manager._newBackgroundActor]) {
        if (actor)
            actor.content.background = background;
    }
}

export function enableBackgrounds(schemes) {
    if (!fieldOfAll(schemes, 'background'))
        return () => {};

    const workspaces = global.workspace_manager;
    // One background per workspace scheme and image crop, made as first needed.
    const backgrounds = new Map();
    const backgroundFor = (workspaceIndex, monitorIndex) => {
        const schemeIndex = workspaceIndex % schemes.length;
        const {background, image} = schemes[schemeIndex];
        const monitor = Main.layoutManager.monitors[monitorIndex];
        const file = image && monitor ? closestCrop(image, monitor).file : null;
        const key = `${schemeIndex} ${file}`;
        if (!backgrounds.has(key))
            backgrounds.set(key, workspaceBackground(background, file));
        return backgrounds.get(key);
    };
    const active = () => workspaces.get_active_workspace_index();
    // Managers following the active workspace, and the per-workspace copies'
    // managers pinned to their own workspace's index.
    const following = new Set(Main.layoutManager._bgManagers);
    const pinned = new WeakMap();
    const pin = (manager, workspace) => {
        following.delete(manager);
        pinned.set(manager, workspace.index());
        pointAt(manager, backgroundFor(workspace.index(), manager._monitorIndex));
    };

    const injections = new InjectionManager();
    injections.overrideMethod(Background.BackgroundManager.prototype, '_createBackgroundActor',
        original => function (...args) {
            const actor = original.call(this, ...args);
            if (!pinned.has(this))
                following.add(this);
            actor.content.background = backgroundFor(pinned.get(this) ?? active(), this._monitorIndex);
            return actor;
        });
    injections.overrideMethod(Background.BackgroundManager.prototype, 'destroy',
        original => function (...args) {
            following.delete(this);
            return original.call(this, ...args);
        });
    injections.overrideMethod(WorkspaceAnimation.WorkspaceBackground.prototype, '_createBackground',
        original => function (...args) {
            original.call(this, ...args);
            pin(this._bgManager, this._workspace);
        });
    // The overview's background doesn't know its workspace; the Workspace
    // holding it does. Secondary monitors may have none.
    injections.overrideMethod(Workspace.Workspace.prototype, '_init',
        original => function (...args) {
            original.call(this, ...args);
            if (this.metaWorkspace)
                pin(this._background._bgManager, this.metaWorkspace);
        });

    // The shell opens the overview at login, before extensions are enabled.
    [...descendants(Main.overview._overview)]
        .filter(actor => actor instanceof Workspace.Workspace && actor.metaWorkspace)
        .forEach(workspace => pin(workspace._background._bgManager, workspace.metaWorkspace));

    // Loaded up front, so no workspace waits for its image when first shown.
    Main.layoutManager.monitors.forEach((monitor, monitorIndex) =>
        schemes.forEach((scheme, schemeIndex) => backgroundFor(schemeIndex, monitorIndex)));

    const follow = () => following.forEach(m => pointAt(m, backgroundFor(active(), m._monitorIndex)));
    const handler = workspaces.connect('active-workspace-changed', follow);
    follow();

    return () => {
        workspaces.disconnect(handler);
        injections.clear();
        // Rebuild from GNOME's own settings.
        following.forEach(m => m._updateBackgroundActor());
    };
}
