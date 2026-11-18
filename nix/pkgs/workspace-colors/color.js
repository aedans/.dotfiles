import Cogl from 'gi://Cogl';

// Colors as [r, g, b] in 0..255.

export function rgb(css) {
    const [, color] = Cogl.Color.from_string(css);
    return [color.red, color.green, color.blue];
}

export function coglColor(color) {
    const [red, green, blue] = color.map(Math.round);
    return new Cogl.Color({red, green, blue, alpha: 255});
}

// The blend of colors, one per scheme, by a weight per scheme (see fade.js).
export function blend(colors, weights) {
    return [0, 1, 2].map(i => colors.reduce((sum, color, s) => sum + color[i] * weights[s], 0));
}
