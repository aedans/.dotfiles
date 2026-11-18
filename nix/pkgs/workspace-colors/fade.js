import Clutter from 'gi://Clutter';
import {WINDOW_ANIMATION_TIME} from 'resource:///org/gnome/shell/ui/workspaceAnimation.js';

import {watchWorkspacePosition} from './position.js';

// The colors of what stays on screen while workspaces slide (the top bar, the
// dock, the cursor) fade together to the scheme of the workspace they're
// heading to, as long as the slide and eased like it. The fade keeps its own
// time rather than following the slide's position, which jumps about as a
// switch starts. What's shown is a blend of schemes, as a weight per scheme: a new heading
// fades on from whatever blend is showing, without passing through the
// workspaces in between. GTK applications fade the same way (see
// stylesheets.nix and gtk-module/terminal.c).

export const FADE_TIME = WINDOW_ANIMATION_TIME;

function only(length, index) {
    return Array.from({length}, (_, i) => (i === index ? 1 : 0));
}

function mix(from, to, t) {
    return from.map((w, i) => w + (to[i] - w) * t);
}

// onFade sees each blend shown, starting with the scheme of the workspace the
// shell starts on.
export function watchSchemeFade(schemes, {onFade}) {
    let shown = null;
    const show = weights => {
        shown = weights;
        onFade(weights);
    };

    let timeline = null;
    const stopFading = () => {
        timeline?.stop();
        timeline = null;
    };
    const fadeTo = target => {
        stopFading();
        const from = shown;
        timeline = new Clutter.Timeline({actor: global.stage, duration: FADE_TIME});
        timeline.set_progress_mode(Clutter.AnimationMode.EASE_OUT_CUBIC);
        timeline.connect('new-frame', () => show(mix(from, target, timeline.get_progress())));
        timeline.connect('completed', () => {
            timeline = null;
            show(target);
        });
        timeline.start();
    };

    const stopWatching = watchWorkspacePosition({
        onHeading: index => {
            const target = only(schemes.length, index % schemes.length);
            if (shown)
                fadeTo(target);
            else
                show(target);
        },
    });

    return () => {
        stopWatching();
        stopFading();
    };
}
