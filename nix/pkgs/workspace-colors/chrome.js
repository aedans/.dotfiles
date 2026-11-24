import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {blend, coglColor, rgb} from './color.js';
import {FADE_TIME, watchSchemeFade} from './fade.js';
import {showDockBackdrop} from './dockBackdrop.js';
import {showPanelBackdrop} from './panelBackdrop.js';
import {watchWorkspacePosition} from './position.js';
import {fieldOfAll} from './schemes.js';
import {coversArea, coversPanel, watchWindowCover} from './windowCover.js';

// The top bar and dock stay on screen while workspaces slide, so their colors
// fade with the cursor's (see fade.js). Restyling them every frame would match
// their whole subtree against the stylesheets each time, so stylesheet.css
// styles them once: the top bar (and the overview's background around the
// workspaces, which matches it) clear, painted here as its actor's background
// color, and the dock white, recolored here by a colorize effect, which keeps
// its rounded shape.
//
// Over blurred wallpapers (see wallpaperStrip.js) they keep their colors,
// translucent, easing in and out of it as long as a workspace fade takes. Each
// is solid while a window is behind it on the workspace being headed to (see
// windowCover.js), so a switch fades its color and its opacity together. As
// the overview shows, following its own progress (gestures included), the top
// bar turns solid where it meets the overview's background, and the dock's
// wallpapers give way to that background.

const DOCK_CONTAINER = 'dashtodockContainer';
const DOCK_EFFECT = 'workspace-colors';

const BLURRED_OPACITY = 0.6;

// Eases a value to each new target, showing every step.
function easedValue(value, show) {
    let timeline = null;
    let target = value;
    const stop = () => {
        timeline?.stop();
        timeline = null;
    };
    const easeTo = to => {
        if (to === target)
            return;
        stop();
        target = to;
        const from = value;
        timeline = new Clutter.Timeline({actor: global.stage, duration: FADE_TIME});
        timeline.set_progress_mode(Clutter.AnimationMode.EASE_OUT_CUBIC);
        timeline.connect('new-frame', () => {
            value = from + (target - from) * timeline.get_progress();
            show();
        });
        timeline.connect('completed', () => {
            timeline = null;
            value = target;
            show();
        });
        timeline.start();
    };
    return {get: () => value, easeTo, stop};
}

function isDock(actor) {
    return actor.name === DOCK_CONTAINER && !!actor.dash?._background;
}

export function enableChrome(schemes) {
    const panelColors = schemes.map(s => rgb(s.panel));
    const dockColors = schemes.map(s => rgb(s.dock));

    let weights = null;
    const paintPanel = () => {
        if (!weights)
            return;
        const color = blend(panelColors, weights);
        Main.panel.set_background_color(coglColor(color, panelOpacity()));
        Main.layoutManager.overviewGroup.set_background_color(coglColor(color));
    };
    // The overview's state runs from 0 (hidden) through 1 (the window picker)
    // to 2 (the app grid), as it animates.
    const overviewState = Main.overview._overview?.controls._stateAdjustment ?? null;
    const overviewProgress = () =>
        Main.overview.visible && overviewState ? Math.min(overviewState.value, 1) : 0;
    let heading = global.workspace_manager.get_active_workspace_index();
    let backdrop = null;
    const panelTarget = () => backdrop?.shown() && !coversPanel(heading) ? BLURRED_OPACITY : 1;
    let blurOpacity = null;
    const easePanel = () => blurOpacity?.easeTo(panelTarget());
    backdrop = showPanelBackdrop(schemes, {onChange: easePanel});
    blurOpacity = easedValue(panelTarget(), () => paintPanel());
    const panelOpacity = () => {
        const blurred = blurOpacity.get();
        return blurred + (1 - blurred) * overviewProgress();
    };
    // Each dock, as its container: {dash, backdrop, target}, target its
    // background's opacity.
    const docks = new Map();
    const paintDock = ({dash}) => {
        const background = dash._background;
        let effect = background.get_effect(DOCK_EFFECT);
        if (!effect) {
            effect = new Clutter.ColorizeEffect();
            background.add_effect_with_name(DOCK_EFFECT, effect);
        }
        effect.tint = coglColor(blend(dockColors, weights));
    };
    const dockTarget = (container, dock) => dock.backdrop
        && !coversArea(heading, container.monitorIndex, container.staticBox)
        ? Math.round(255 * BLURRED_OPACITY) : 255;
    const easeDocks = () => docks.forEach((dock, container) => {
        const target = dockTarget(container, dock);
        if (target === dock.target)
            return;
        dock.target = target;
        dock.dash._background.ease({
            opacity: target,
            duration: FADE_TIME,
            mode: Clutter.AnimationMode.EASE_OUT_CUBIC,
        });
    });
    const fadeDockBackdrops = () => docks.forEach(({backdrop}) => {
        if (backdrop)
            backdrop.actor.opacity = Math.round(255 * (1 - overviewProgress()));
    });
    const easeChrome = () => {
        easePanel();
        easeDocks();
    };
    const stopWatchingPosition = watchWorkspacePosition({
        onHeading: index => {
            heading = index;
            easeChrome();
        },
    });
    const paint = () => {
        paintPanel();
        docks.forEach(paintDock);
    };
    const followOverview = () => {
        paintPanel();
        fadeDockBackdrops();
    };

    const owner = {};
    const watchDock = container => {
        const {dash} = container;
        const backdrop = fieldOfAll(schemes, 'background')
            ? showDockBackdrop(schemes, dash, container.monitorIndex) : null;
        const dock = {dash, backdrop, target: null};
        docks.set(container, dock);
        container.connectObject('destroy', () => docks.delete(container), owner);
        dock.target = dockTarget(container, dock);
        dash._background.opacity = dock.target;
        paintDock(dock);
        fadeDockBackdrops();
    };
    const stopWatchingCover = watchWindowCover(easeChrome);
    overviewState?.connectObject('notify::value', followOverview, owner);
    Main.overview.connectObject('hidden', followOverview, owner);
    // Dash-to-dock recreates its docks on some of its settings changes.
    Main.uiGroup.connectObject('child-added', (group, child) => {
        if (isDock(child))
            watchDock(child);
    }, owner);

    const stopWatching = watchSchemeFade(schemes, {
        onFade: w => {
            weights = w;
            paint();
        },
    });
    Main.uiGroup.get_children().filter(isDock).forEach(watchDock);

    return () => {
        stopWatching();
        stopWatchingPosition();
        stopWatchingCover();
        blurOpacity.stop();
        backdrop.destroy();
        overviewState?.disconnectObject(owner);
        Main.overview.disconnectObject(owner);
        Main.uiGroup.disconnectObject(owner);
        [Main.panel, Main.layoutManager.overviewGroup].forEach(actor => actor.set_background_color(null));
        docks.forEach(({dash, backdrop}, container) => {
            container.disconnectObject(owner);
            backdrop?.destroy();
            dash._background.remove_effect_by_name(DOCK_EFFECT);
            dash._background.remove_all_transitions();
            dash._background.opacity = 255;
        });
        docks.clear();
    };
}
