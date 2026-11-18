import Clutter from 'gi://Clutter';
import Cogl from 'gi://Cogl';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {colorAt, rgb} from './color.js';
import {watchWorkspacePosition} from './position.js';

// The top bar and dock stay on screen while workspaces slide, so their colors
// blend along the workspace position. Restyling them every frame would match
// their whole subtree against the stylesheets each time, so stylesheet.css
// styles them once: the top bar (and the overview's background around the
// workspaces, which matches it) clear, painted here as its actor's background
// color, and the dock white, recolored here by a colorize effect, which keeps
// its rounded shape.

const DOCK_CONTAINER = 'dashtodockContainer';
const DOCK_EFFECT = 'workspace-colors';

function coglColor(color) {
    const [red, green, blue] = color.map(Math.round);
    return new Cogl.Color({red, green, blue, alpha: 255});
}

// The top bar and the overview's background around the workspaces, which
// meet seamlessly in the top bar's color.
function panelColored() {
    return [Main.panel, Main.layoutManager.overviewGroup];
}

function dockBackground(container) {
    return container.name === DOCK_CONTAINER ? container.dash?._background ?? null : null;
}

function dockBackgrounds() {
    return Main.uiGroup.get_children().map(dockBackground).filter(Boolean);
}

export function enableChrome(schemes) {
    const panelColors = schemes.map(s => rgb(s.panel));
    const dockColors = schemes.map(s => rgb(s.dock));

    let position = global.workspace_manager.get_active_workspace_index();
    const paintDock = background => {
        let effect = background.get_effect(DOCK_EFFECT);
        if (!effect) {
            effect = new Clutter.ColorizeEffect();
            background.add_effect_with_name(DOCK_EFFECT, effect);
        }
        effect.tint = coglColor(colorAt(dockColors, position));
    };
    const paint = () => {
        const panelColor = coglColor(colorAt(panelColors, position));
        panelColored().forEach(actor => actor.set_background_color(panelColor));
        dockBackgrounds().forEach(paintDock);
    };

    // Dash-to-dock recreates its docks on some of its settings changes.
    const owner = {};
    Main.uiGroup.connectObject('child-added', (group, child) => {
        const background = dockBackground(child);
        if (background)
            paintDock(background);
    }, owner);

    const stopWatching = watchWorkspacePosition({
        onMove: p => {
            position = p;
            paint();
        },
    });

    return () => {
        stopWatching();
        Main.uiGroup.disconnectObject(owner);
        panelColored().forEach(actor => actor.set_background_color(null));
        dockBackgrounds().forEach(background => background.remove_effect_by_name(DOCK_EFFECT));
    };
}
