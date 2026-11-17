import Clutter from 'gi://Clutter';
import Cogl from 'gi://Cogl';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {colorAt, rgb} from './color.js';
import {watchWorkspacePosition} from './position.js';
import {fieldOfAll} from './schemes.js';

// The top bar and dock stay on screen while workspaces slide, so their colors
// blend along the workspace position. Restyling them every frame would match
// their whole subtree against the shell's stylesheet each time (and the
// themes' scoped copies of it make that slow), so their styles are set once:
// the top bar's background (and the overview's, which matches it) is cleared
// and painted as its actor's background color, and the dock's is white, recolored by a colorize effect, which keeps
// its rounded shape. Neither is written to dash-to-dock's settings: a settings
// change makes it rebuild its style, which shows the dock at the wrong width
// for a frame.

const DOCK_CONTAINER = 'dashtodockContainer';

// GNOME gives each dock icon a tile in its own dock's grey, which shows as a
// square on any other dock color, and a hover highlight in a fixed lighter
// grey. Here the tile is clear and the highlight a translucent white, so it
// has the same contrast on every dock. Themes copy this after the shell's own
// rules (see shellTheme.js), so it wins.
export const DOCK_STYLESHEET = `
#dash .dash-item-container .show-apps .overview-icon,
#dash .dash-item-container .overview-tile .overview-icon {
  background-color: rgba(255, 255, 255, 0);
}
#dash .dash-item-container .show-apps:hover .overview-icon,
#dash .dash-item-container .overview-tile:hover .overview-icon {
  background-color: rgba(255, 255, 255, 0.1);
}
`;
// Our declarations go last in the actor's inline style, so they win while the
// rest of it (dash-to-dock keeps its own there) is preserved. St's transition
// is turned off: it would crossfade the style we set once.
const OWN_DECLARATIONS = /\s*(background-color|border-color|transition-duration)\s*:[^;]*;?/g;
const PANEL_STYLE = 'background-color: transparent; transition-duration: 0ms;';
// The dock's border takes its color, as dash-to-dock's does.
const DOCK_STYLE = 'background-color: white; border-color: white; transition-duration: 0ms;';
const DOCK_EFFECT = 'workspace-colors';

function othersStyle(actor) {
    return (actor.get_style() ?? '').replace(OWN_DECLARATIONS, '').trim();
}

function setStyle(actor, style) {
    actor.set_style(style.trim() || null);
}

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
    const panelColors = fieldOfAll(schemes, 'panel')?.map(rgb);
    const dockColors = fieldOfAll(schemes, 'dock')?.map(rgb);

    // Actors given our inline style. When another extension replaces an
    // actor's inline style, ours is put back on top.
    const owner = {};
    const styled = new Map();
    const style = (actor, own) => {
        if (styled.has(actor))
            return;
        styled.set(actor, own);
        const apply = () => {
            if (!actor.get_style()?.endsWith(own))
                setStyle(actor, `${othersStyle(actor)} ${own}`);
        };
        actor.connectObject('notify::style', apply, 'destroy', () => styled.delete(actor), owner);
        apply();
    };

    let position = global.workspace_manager.get_active_workspace_index();
    const paintPanel = () => {
        const color = coglColor(colorAt(panelColors, position));
        for (const actor of panelColored()) {
            style(actor, PANEL_STYLE);
            actor.background_color = color;
        }
    };
    const paintDock = background => {
        style(background, DOCK_STYLE);
        let effect = background.get_effect(DOCK_EFFECT);
        if (!effect) {
            effect = new Clutter.ColorizeEffect();
            background.add_effect_with_name(DOCK_EFFECT, effect);
        }
        effect.tint = coglColor(colorAt(dockColors, position));
    };
    const paint = () => {
        if (panelColors)
            paintPanel();
        if (dockColors)
            dockBackgrounds().forEach(paintDock);
    };

    // Dash-to-dock recreates its docks on some of its settings changes.
    Main.uiGroup.connectObject('child-added', (group, child) => {
        const background = dockColors && dockBackground(child);
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
        styled.forEach((own, actor) => {
            actor.disconnectObject(owner);
            actor.remove_effect_by_name(DOCK_EFFECT);
            setStyle(actor, othersStyle(actor));
        });
    };
}
