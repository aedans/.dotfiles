import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {enableBackgrounds} from './backgrounds.js';
import {enableChrome} from './chrome.js';
import {enableCursor} from './cursor.js';
import {readSchemes} from './schemes.js';
import {enableShellTheme} from './shellTheme.js';
import {enableWindowThemes} from './windowThemes.js';

// GNOME requires extensions to be a default-exported Extension subclass.
// It stays enabled on the lock screen (session-modes in metadata.json), which
// otherwise falls back to the first workspace's colors and background.
export default class WorkspaceColors extends Extension {
    enable() {
        const schemes = readSchemes(this.dir);
        this._disablers = [
            enableBackgrounds(schemes),
            enableChrome(schemes),
            enableCursor(this.dir, schemes),
            enableShellTheme(schemes),
            enableWindowThemes(schemes),
        ];
    }

    disable() {
        this._disablers.reverse().forEach(disable => disable());
        this._disablers = null;
    }
}
