import Meta from 'gi://Meta';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// Whether a workspace has a window behind the top bar or the dock. For the
// bar, a window shown on its monitor whose top comes within a few pixels of
// the bar's bottom, as Blur my Shell judges it to turn the bar solid; for the
// dock, one overlapping where the dock shows. Judging any workspace, not just
// the active one, lets them turn solid or clear as a switch heads there, along
// with their colors. A new window counts once it's first shown:
// until mutter places it, it's at the top of the screen.

const MARGIN = 5;
const COVERING_TYPES = [Meta.WindowType.NORMAL, Meta.WindowType.DIALOG, Meta.WindowType.MODAL_DIALOG];

// New windows not yet shown.
const unshown = new WeakSet();

// Whether a window on the workspace and monitor has a frame rect such that
// covers(rect).
function anyWindow(index, monitor, covers) {
    const workspace = global.workspace_manager.get_workspace_by_index(index);
    return !!workspace?.list_windows().some(window =>
        !unshown.has(window)
        && window.get_monitor() === monitor
        && window.showing_on_its_workspace()
        && COVERING_TYPES.includes(window.get_window_type())
        && covers(window.get_frame_rect()));
}

export function coversPanel(index) {
    const margin = MARGIN * St.ThemeContext.get_for_stage(global.stage).scale_factor;
    const bottom = Main.panel.get_transformed_position()[1] + Main.panel.height;
    return anyWindow(index, Main.layoutManager.primaryIndex, rect => rect.y < bottom + margin);
}

// box: a Clutter.ActorBox on the stage.
export function coversArea(index, monitor, box) {
    return anyWindow(index, monitor, rect =>
        rect.x < box.x2 && rect.x + rect.width > box.x1
        && rect.y < box.y2 && rect.y + rect.height > box.y1);
}

// onChange runs whenever a window may have started or stopped covering the top
// bar or dock: it was shown, removed, moved, resized, minimized or restored. A window
// going away is still on its workspace as it says so, so that waits until
// before the next frame.
export function watchWindowCover(onChange) {
    const owner = {};
    const laters = global.compositor.get_laters();
    let later = 0;
    const onChangeLater = () => {
        later ||= laters.add(Meta.LaterType.BEFORE_REDRAW, () => {
            later = 0;
            onChange();
            return false;
        });
    };
    const track = window => window.connectObject(
        'position-changed', onChange,
        'size-changed', onChange,
        'notify::minimized', onChange,
        'workspace-changed', onChange,
        'unmanaged', () => {
            window.disconnectObject(owner);
            onChangeLater();
        }, owner);

    global.display.connectObject('window-created', (display, window) => {
        unshown.add(window);
        window.connectObject('shown', () => {
            unshown.delete(window);
            onChange();
        }, owner);
        track(window);
    }, owner);
    global.get_window_actors().forEach(actor => track(actor.meta_window));

    return () => {
        if (later)
            laters.remove(later);
        global.display.disconnectObject(owner);
        global.get_window_actors().forEach(actor => actor.meta_window.disconnectObject(owner));
    };
}
