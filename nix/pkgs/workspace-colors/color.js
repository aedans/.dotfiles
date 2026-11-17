import Cogl from 'gi://Cogl';

// Colors as [r, g, b] in 0..255, blended along the workspace position.

export function rgb(css) {
    const [, color] = Cogl.Color.from_string(css);
    return [color.red, color.green, color.blue];
}

// The color at a fractional workspace position, between the colors of the
// workspaces either side of it; workspaces past the end wrap around.
export function colorAt(colors, position) {
    const lower = Math.floor(position);
    const from = colors[lower % colors.length];
    const to = colors[(lower + 1) % colors.length];
    const t = position - lower;
    return from.map((c, i) => c + (to[i] - c) * t);
}
