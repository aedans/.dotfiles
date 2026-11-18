import Cogl from 'gi://Cogl';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import * as Background from 'resource:///org/gnome/shell/ui/background.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {fieldOfAll, schemeAt} from './schemes.js';

// Each workspace shows its scheme's wallpaper through the shell's
// per-workspace backgrounds (see patches/workspace-backgrounds.patch).
//
// GNOME shows the background from gsettings until extensions enable, so that
// is kept as the image the first workspace shows on the primary monitor.

const SETTINGS_SCHEMA = 'org.gnome.desktop.background';
const SETTINGS_KEYS = ['picture-uri', 'picture-uri-dark'];

// The crop (see default.nix) whose shape is closest to the monitor's, so that
// zooming it to fill the monitor cuts off little more than the crop chose to.
function closestCrop(crops, monitor) {
    const mismatch = crop => Math.abs(Math.log(crop.aspect * monitor.height / monitor.width));
    return crops.reduce((best, crop) => mismatch(crop) < mismatch(best) ? crop : best);
}

// The image, zoomed to fill the monitor, over the color, which shows until
// the image has loaded.
function backgroundOf({background, image}, monitor) {
    const [, color] = Cogl.Color.from_string(background);
    const file = image && monitor ? Gio.File.new_for_path(closestCrop(image, monitor).file) : null;
    return {file, color};
}

function keepStartupBackground(file) {
    const settings = new Gio.Settings({schema_id: SETTINGS_SCHEMA});
    const uri = file.get_uri();
    SETTINGS_KEYS.filter(key => settings.get_string(key) !== uri)
        .forEach(key => settings.set_string(key, uri));
}

export function enableBackgrounds(schemes) {
    if (!fieldOfAll(schemes, 'background'))
        return () => {};

    // Loaded up front and held until disabled, so no workspace waits for its
    // image when first shown.
    const cache = Meta.BackgroundImageCache.get_default();
    const preloaded = Main.layoutManager.monitors
        .flatMap(monitor => schemes.map(scheme => backgroundOf(scheme, monitor).file))
        .filter(Boolean)
        .map(file => cache.load(file));

    Background.setWorkspaceBackgrounds((index, monitor) => backgroundOf(schemeAt(schemes, index), monitor));

    const startup = backgroundOf(schemes[0], Main.layoutManager.primaryMonitor);
    if (startup.file)
        keepStartupBackground(startup.file);

    return () => {
        Background.setWorkspaceBackgrounds(null);
        preloaded.length = 0;
    };
}
