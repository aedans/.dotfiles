import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import {schemeAt} from './schemes.js';

// Tells GTK applications running the workspace-theme module which theme each
// of their windows should wear: its workspace's theme. The module animates
// the change, so a window moved between workspaces fades to the new theme.
// Application windows are named by their GTK object path. Dialogs without one,
// such as file pickers the desktop portal shows for another application, and
// the windows of the GTK applications in TITLED_APPS, are named by title to
// the process showing them; other windows without one are left alone, which
// keeps applications that draw their own look (Firefox, Electron's) as they
// are while their dialogs follow the workspace. Windows on all workspaces, and
// processes without the module, are left alone too.

const OBJECT_PATH = '/org/hans/WorkspaceTheme';
const INTERFACE = 'org.hans.WorkspaceTheme';
const PROCESS_BUS_PREFIX = 'org.hans.WorkspaceTheme.P';
// Window classes of plain GTK applications without a GTK object path.
const TITLED_APPS = new Set(['qemu', 'nm-connection-editor']);

function themeOf(schemes, window) {
    const workspace = window.is_on_all_workspaces() ? null : window.get_workspace();
    return workspace ? schemeAt(schemes, workspace.index()).theme ?? '' : '';
}

function call(bus, method, parameters) {
    Gio.DBus.session.call(bus, OBJECT_PATH, INTERFACE, method,
        new GLib.Variant('(ss)', parameters), null,
        Gio.DBusCallFlags.NO_AUTO_START, -1, null,
        (connection, result) => {
            try {
                connection.call_finish(result);
            } catch {
                // The process has no module, or no such window.
            }
        });
}

function sendTheme(window, theme) {
    const bus = window.get_gtk_unique_bus_name();
    const path = window.get_gtk_window_object_path();
    if (bus && path)
        call(bus, 'SetWindowTheme', [path, theme]);
    else if ((window.get_transient_for() || TITLED_APPS.has(window.get_wm_class())) && window.get_pid() > 0)
        call(`${PROCESS_BUS_PREFIX}${window.get_pid()}`, 'SetToplevelTheme', [window.get_title() ?? '', theme]);
}

export function enableWindowThemes(schemes) {
    if (!schemes.some(s => s.theme !== undefined))
        return () => {};

    const owner = {};
    const windows = new Set();
    const update = window => sendTheme(window, themeOf(schemes, window));
    const track = window => {
        windows.add(window);
        window.connectObject(
            'workspace-changed', () => update(window),
            'notify::gtk-window-object-path', () => update(window),
            'notify::gtk-unique-bus-name', () => update(window),
            // Only windows named by title. A window's class can arrive after
            // its title, deciding whether it's named by title at all.
            'notify::title', () => {
                if (!window.get_gtk_window_object_path())
                    update(window);
            },
            'notify::wm-class', () => {
                if (!window.get_gtk_window_object_path())
                    update(window);
            },
            'unmanaged', () => {
                window.disconnectObject(owner);
                windows.delete(window);
            }, owner);
        update(window);
    };

    global.display.connectObject('window-created', (display, window) => track(window), owner);
    global.get_window_actors().forEach(actor => track(actor.meta_window));

    return () => {
        global.display.disconnectObject(owner);
        windows.forEach(window => {
            window.disconnectObject(owner);
            sendTheme(window, '');
        });
    };
}
