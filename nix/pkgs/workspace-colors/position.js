import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// The shell's fractional workspace position, which the switch animation
// (touchpad swipes included) and the overview both drive. onMove sees every
// position; onHeading each workspace index the position is on its way to. A switch
// (e.g. from the keyboard) activates the target workspace before the position
// leaves the old one, so it heads there from the start; a swipe heads to
// whichever workspace is nearer, until it activates one.

// After a switch, how long to wait for the position to arrive before assuming
// it never will (e.g. with animations disabled).
const SETTLE_FALLBACK_MS = 500;

export function watchWorkspacePosition({onMove = () => {}, onHeading = () => {}}) {
    const workspaces = global.workspace_manager;
    let headingIndex = null;
    // Whether a switch has activated a workspace the position hasn't reached.
    let switching = false;
    const head = index => {
        if (index !== headingIndex) {
            headingIndex = index;
            onHeading(index);
        }
    };
    const update = position => {
        onMove(position);
        const index = Math.round(position);
        // A switch may still report the workspace it leaves.
        if (switching && index !== workspaces.get_active_workspace_index())
            return;
        if (Math.abs(position - index) < 1e-6) {
            switching = false;
            head(index);
        } else if (!switching) {
            head(index);
        }
    };

    const adjustment = Main.createWorkspacesAdjustment(Main.panel);
    const valueHandler = adjustment.connect('notify::value', () => update(adjustment.value));
    let fallback = 0;
    const switchHandler = workspaces.connect('active-workspace-changed', () => {
        const active = workspaces.get_active_workspace_index();
        switching = Math.abs(adjustment.value - active) > 1e-6;
        head(active);
        if (fallback)
            GLib.source_remove(fallback);
        fallback = GLib.timeout_add(GLib.PRIORITY_DEFAULT, SETTLE_FALLBACK_MS, () => {
            fallback = 0;
            const active = workspaces.get_active_workspace_index();
            if (Math.abs(adjustment.value - active) > 1e-6)
                update(active);
            return GLib.SOURCE_REMOVE;
        });
    });
    update(workspaces.get_active_workspace_index());

    return () => {
        if (fallback)
            GLib.source_remove(fallback);
        workspaces.disconnect(switchHandler);
        adjustment.disconnect(valueHandler);
    };
}
