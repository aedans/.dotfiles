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
// and radius in its own pixels, smoothing the edge over a pixel. Clutter
// paints it into a texture padded past it (see texture below), whose own
// coordinates are what the shader sees.
//
// The background over it smooths the same edge, at its opacity, so where a
// pixel is partly covered the two would let through more of this than one
// smoothed shape would. Covering a of a pixel with (1 - o) a / (1 - o a) here,
// under the background's o a, composites as the pair covering a together.
const CORNERS_DECLARATIONS = `
uniform vec2 size;
uniform float radius;
uniform vec2 textureOrigin;
uniform vec2 textureSize;
uniform float overOpacity;
`;
const CORNERS_CODE = `
vec2 p = textureOrigin + cogl_tex_coord_in[0].xy * textureSize;
vec2 q = abs(p - 0.5 * size) - (0.5 * size - radius);
float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
float a = clamp(0.5 - d, 0.0, 1.0);
cogl_color_out *= a >= 1.0 ? 1.0 : (1.0 - overOpacity) * a / (1.0 - overOpacity * a);
`;

// Where Clutter's offscreen texture for an effect starts along an actor's side
// of the given length, from 0, and how long it is: the side rounded, padded
// by 3 pixels, and ending past it (see _clutter_actor_box_enlarge_for_effects
// in mutter). It pads what the actor paints, which here is its own box, as
// the strip is clipped to it.
function texture(length) {
    const extent = Math.round(length) + 3;
    return [Math.ceil(length + 0.75) - extent, extent];
}

// GNOME requires effects with their own shaders to be GObject subclasses.
const RoundedCorners = GObject.registerClass(
class RoundedCorners extends Shell.GLSLEffect {
    _init() {
        super._init();
        this._sizeLocation = this.get_uniform_location('size');
        this._radiusLocation = this.get_uniform_location('radius');
        this._textureOriginLocation = this.get_uniform_location('textureOrigin');
        this._textureSizeLocation = this.get_uniform_location('textureSize');
        this._overOpacityLocation = this.get_uniform_location('overOpacity');
        this._shape = null;
        this._overOpacity = null;
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
        const [x, w] = texture(width);
        const [y, h] = texture(height);
        this.set_uniform_float(this._textureOriginLocation, 2, [x, y]);
        this.set_uniform_float(this._textureSizeLocation, 2, [w, h]);
        this.queue_repaint();
    }

    // The opacity of what's over it, from 0 to 1.
    setOverOpacity(opacity) {
        if (opacity === this._overOpacity)
            return;
        this._overOpacity = opacity;
        this.set_uniform_float(this._overOpacityLocation, 1, [opacity]);
        this.queue_repaint();
    }
});

// Returns {actor, destroy}; the actor's opacity is the backdrop's.
export function showDockBackdrop(schemes, dash, monitorIndex) {
    const background = dash._background;
    const strip = createWallpaperStrip(schemes, () => monitorIndex);
    // The dash fills its expanding children's room, less their margins, and
    // centers the rest at their own size, which the background's fills. With
    // the background's margins, expanding fills the same in the same layout
    // pass; a constraint bound to the background, laid out after this, would
    // see its size from the pass before. The margins are on a plain actor, as
    // St sets its widgets' margins from their styles. The strip asks for no
    // size, so it's bound to this, laid out before it.
    const actor = new Clutter.Actor({x_expand: true, y_expand: true});
    const fit = () => {
        const sides = ['margin_top', 'margin_right', 'margin_bottom', 'margin_left'];
        actor.set(Object.fromEntries(sides.map(side => [side, background[side]])));
    };
    fit();
    strip.actor.add_constraint(new Clutter.BindConstraint({
        source: actor,
        coordinate: Clutter.BindCoordinate.SIZE,
    }));
    actor.add_child(strip.actor);
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
        const box = actor.get_allocation_box();
        const radius = background.get_theme_node().get_border_radius(St.Corner.TOPLEFT);
        corners.setShape(box.get_width(), box.get_height(), radius);
        corners.setOverOpacity(background.opacity / 255);
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
