import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {fieldOfAll} from './schemes.js';
import {createWallpaperStrip} from './wallpaperStrip.js';

// What the top bar shows through it while translucent: its monitor's
// wallpapers (see wallpaperStrip.js). They're shown while the bar is, except
// on the lock screen, whose own background is behind the bar.

// onChange: whenever it's shown or hidden. Returns {shown, destroy}.
export function showPanelBackdrop(schemes, {onChange}) {
    if (!fieldOfAll(schemes, 'background'))
        return {shown: () => false, destroy: () => {}};

    const {layoutManager} = Main;
    const {panelBox} = layoutManager;
    const strip = createWallpaperStrip(schemes, () => layoutManager.primaryIndex);
    strip.actor.add_constraint(new Clutter.BindConstraint({
        source: panelBox,
        coordinate: Clutter.BindCoordinate.ALL,
    }));
    layoutManager.uiGroup.insert_child_below(strip.actor, panelBox);
    // Both are in the stage's own coordinates.
    const place = () => strip.setOrigin(panelBox.x, panelBox.y);

    const shown = () => panelBox.visible && !Main.sessionMode.isLocked && !!layoutManager.primaryMonitor;
    const sync = () => {
        const visible = shown();
        if (visible !== strip.actor.visible) {
            strip.actor.visible = visible;
            onChange();
        }
    };

    strip.actor.visible = shown();
    place();

    const owner = {};
    panelBox.connectObject('notify::visible', sync, 'notify::position', place, owner);
    Main.sessionMode.connectObject('updated', sync, owner);
    layoutManager.connectObject('monitors-changed', sync, owner);

    return {
        shown: () => strip.actor.visible,
        destroy: () => {
            [panelBox, Main.sessionMode, layoutManager].forEach(o => o.disconnectObject(owner));
            strip.destroy();
        },
    };
}
