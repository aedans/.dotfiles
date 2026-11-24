import Clutter from 'gi://Clutter';
import Cogl from 'gi://Cogl';
import GObject from 'gi://GObject';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {createWallpaperStrip} from './wallpaperStrip.js';

// What a dash-to-dock dock shows through its background while translucent: its
// monitor's wallpapers (see wallpaperStrip.js), rounded like the background
// and following it as the dock slides in and out.

// Fades out what it's applied to past a rounded rectangle filling it, of size
// and radius in its own pixels, smoothing the edge over a pixel.
const CORNERS_DECLARATIONS = `
uniform vec2 size;
uniform float radius;
`;
const CORNERS_CODE = `
vec2 p = cogl_tex_coord_in[0].xy * size;
vec2 q = abs(p - 0.5 * size) - (0.5 * size - radius);
float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
cogl_color_out *= clamp(0.5 - d, 0.0, 1.0);
`;

// GNOME requires effects with their own shaders to be GObject subclasses.
const RoundedCorners = GObject.registerClass(
class RoundedCorners extends Shell.GLSLEffect {
    _init() {
        super._init();
        this._sizeLocation = this.get_uniform_location('size');
        this._radiusLocation = this.get_uniform_location('radius');
        this._shape = null;
    }

    vfunc_build_pipeline() {
        this.add_glsl_snippet(Cogl.SnippetHook.FRAGMENT, CORNERS_DECLARATIONS, CORNERS_CODE, false);
    }

    setShape(width, height, radius) {
        const shape = `${width} ${height} ${radius}`;
        if (shape === this._shape)
            return;
        this._shape = shape;
        this.set_uniform_float(this._sizeLocation, 2, [width, height]);
        this.set_uniform_float(this._radiusLocation, 1, [Math.min(radius, width / 2, height / 2)]);
        this.queue_repaint();
    }
});

// Returns {actor, destroy}; the actor's opacity is the backdrop's.
export function showDockBackdrop(schemes, dash, monitorIndex) {
    const background = dash._background;
    const strip = createWallpaperStrip(schemes, () => monitorIndex);
    // The dash fills its children's room, less their margins, so with the
    // background's margins this fills the same. They're on a plain actor, as
    // St sets its widgets' margins from their styles.
    const actor = new Clutter.Actor({layout_manager: new Clutter.BinLayout()});
    actor.add_child(strip.actor);
    const fit = () => {
        const sides = ['margin_top', 'margin_right', 'margin_bottom', 'margin_left'];
        actor.set(Object.fromEntries(sides.map(side => [side, background[side]])));
    };
    actor.set({x_expand: background.x_expand, y_expand: background.y_expand});
    fit();
    const corners = new RoundedCorners();
    actor.add_effect(corners);
    dash.insert_child_below(actor, background);

    // Where the dock is on the stage is only known once it's laid out for the
    // frame, after it's slid; following it there places the wallpapers for the
    // same frame.
    const follow = () => {
        if (!actor.is_mapped())
            return;
        const [x, y] = actor.get_transformed_position();
        strip.setOrigin(x, y);
        // Its own width and height are the none it asks for in the layout.
        const box = actor.get_allocation_box();
        const radius = background.get_theme_node().get_border_radius(St.Corner.TOPLEFT);
        corners.setShape(box.get_width(), box.get_height(), radius);
    };
    const owner = {};
    let destroyed = false;
    const destroy = () => {
        if (destroyed)
            return;
        destroyed = true;
        [global.stage, background, actor].forEach(o => o.disconnectObject(owner));
        strip.destroy();
        actor.destroy();
    };
    global.stage.connectObject('before-paint', follow, owner);
    background.connectObject('style-changed', fit, owner);
    // Dash-to-dock destroys its docks on some of its settings changes.
    actor.connectObject('destroy', destroy, owner);

    return {actor, destroy};
}
