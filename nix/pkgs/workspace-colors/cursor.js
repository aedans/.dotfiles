import {blend, coglColor, rgb} from './color.js';
import {watchSchemeFade} from './fade.js';
import {fieldOfAll} from './schemes.js';

// The cursor's accent fades with the top bar and dock (see fade.js): mutter
// swaps the cursor theme's accent color for it (see
// patches/cursor-recolor.patch). cursor.json names the theme's accent. Cursors
// that clients draw themselves, such as X11 applications', keep their own
// colors.

function readAccent(dir) {
    const [, bytes] = dir.get_child('cursor.json').load_contents(null);
    return JSON.parse(new TextDecoder().decode(bytes)).accent;
}

export function enableCursor(dir, schemes) {
    const cursors = fieldOfAll(schemes, 'cursor');
    if (!cursors)
        return () => {};

    const accent = coglColor(rgb(readAccent(dir)));
    const colors = cursors.map(rgb);
    const tracker = global.backend.get_cursor_tracker();
    const stopWatching = watchSchemeFade(schemes, {
        onFade: weights => tracker.set_recolor(accent, coglColor(blend(colors, weights))),
    });

    return () => {
        stopWatching();
        tracker.set_recolor(null, null);
    };
}
