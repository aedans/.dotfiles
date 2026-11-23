import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';

import {schemeAt} from './schemes.js';

// Tells GTK applications running the workspace-theme module, and Qt
// applications running the workspace-theme plugin, which theme each of their
// windows should wear: its workspace's theme. Both animate the change, so a
// window moved between workspaces fades to the new theme. GTK application
// windows are named by their GTK object path. Dialogs without one, such as
// file pickers the desktop portal shows for another application, and the
// windows of the GTK applications in TITLED_APPS, are named by title to the
// process showing them; other GTK windows without one are left alone, which
// keeps applications that draw their own look (Firefox, Electron's) as they
// are while their dialogs follow the workspace. Every window of a Qt
// application is named by title to its process's plugin. Mutter draws the
// title bars of X11 windows in a GTK process of its own, which the module
// themes too: each title bar is named by its window's title. A window is named
// only once it's shown, so its process is told the theme of its focused window
// ahead of time, which the module gives its dialogs, and the plugin its
// windows, as they're shown. Windows on all workspaces, and processes without
// the module or plugin, are left alone too.

const OBJECT_PATH = '/org/hans/WorkspaceTheme';
const INTERFACE = 'org.hans.WorkspaceTheme';
const GTK_PROCESS_BUS_PREFIX = 'org.hans.WorkspaceTheme.P';
const QT_PROCESS_BUS_PREFIX = 'org.hans.WorkspaceTheme.Qt';
// The process drawing X11 windows' title bars.
const FRAMES_BUS = 'org.hans.WorkspaceTheme.Frames';
// Window classes of plain GTK applications without a GTK object path.
// LibreOffice's are its components'; its title bar and menu bar are GTK's.
const TITLED_APPS = new Set(['qemu', 'nm-connection-editor', 'gsconnect',
    'org.pulseaudio.pavucontrol',
    ...['startcenter', 'writer', 'calc', 'impress', 'draw', 'math', 'base']
        .map(component => `libreoffice-${component}`)]);

function themeOf(schemes, window) {
    const workspace = window.is_on_all_workspaces() ? null : window.get_workspace();
    return workspace ? schemeAt(schemes, workspace.index()).theme ?? '' : '';
}

function call(bus, method, parameters) {
    Gio.DBus.session.call(bus, OBJECT_PATH, INTERFACE, method,
        new GLib.Variant(`(${'s'.repeat(parameters.length)})`, parameters), null,
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
    const pid = window.get_pid();
    const title = window.get_title() ?? '';
    if (window.get_client_type() === Meta.WindowClientType.X11 && window.decorated)
        call(FRAMES_BUS, 'SetToplevelTheme', [title, theme]);
    if (bus && path) {
        call(bus, 'SetWindowTheme', [path, theme]);
        return;
    }
    if (pid <= 0)
        return;
    if (window.get_transient_for() || TITLED_APPS.has(window.get_wm_class()))
        call(`${GTK_PROCESS_BUS_PREFIX}${pid}`, 'SetToplevelTheme', [title, theme]);
    call(`${QT_PROCESS_BUS_PREFIX}${pid}`, 'SetToplevelTheme', [title, theme]);
}

// The process buses of an application's own window that GTK doesn't name,
// whose new windows the shell can only name once they're shown.
function unnamedProcessBuses(window) {
    const pid = window.get_pid();
    if (window.get_gtk_window_object_path() || window.get_transient_for() || pid <= 0)
        return [];
    return [`${GTK_PROCESS_BUS_PREFIX}${pid}`, `${QT_PROCESS_BUS_PREFIX}${pid}`];
}

export function enableWindowThemes(schemes) {
    if (!schemes.some(s => s.theme !== undefined))
        return () => {};

    const owner = {};
    const windows = new Set();
    // Process buses told a theme, to clear when disabled.
    const processes = new Set();
    const updateProcess = () => {
        const window = global.display.focus_window;
        for (const bus of window ? unnamedProcessBuses(window) : []) {
            processes.add(bus);
            call(bus, 'SetProcessTheme', [themeOf(schemes, window)]);
        }
    };
    const update = window => {
        sendTheme(window, themeOf(schemes, window));
        if (window === global.display.focus_window)
            updateProcess();
    };
    const track = window => {
        windows.add(window);
        window.connectObject(
            'workspace-changed', () => update(window),
            'notify::gtk-window-object-path', () => update(window),
            'notify::gtk-unique-bus-name', () => update(window),
            // Only windows named by title. A window's class or parent can
            // arrive after its title, deciding whether it's named by title at
            // all: Electron's dialogs on Wayland get their parent once it's
            // exported to them, after they're shown.
            'notify::title', () => {
                if (!window.get_gtk_window_object_path())
                    update(window);
            },
            'notify::transient-for', () => {
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

    global.display.connectObject(
        'window-created', (display, window) => track(window),
        'notify::focus-window', updateProcess,
        owner);
    global.get_window_actors().forEach(actor => track(actor.meta_window));
    updateProcess();

    return () => {
        global.display.disconnectObject(owner);
        windows.forEach(window => {
            window.disconnectObject(owner);
            sendTheme(window, '');
        });
        processes.forEach(bus => call(bus, 'SetProcessTheme', ['']));
    };
}
