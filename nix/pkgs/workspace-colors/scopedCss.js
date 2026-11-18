// Per-theme copies of the shell's color cascade, scoped under ws-<theme>.
//
// Every color declaration of every given stylesheet is copied, in order, with
// one class prepended to each selector. Raising all of them by the same
// specificity keeps each override in place: a rule that resets a color (often
// to a keyword like `transparent`) still beats the one it resets, including
// across extension stylesheets. Neutral greys keep their lightness but take
// the theme's tint, and the accent replaces -st-accent-color. Layout is never
// copied, so a theme only changes colors.
//
// The first workspace's copy is also baked, unscoped, into the shell's own
// stylesheet (see bake.mjs), so the shell wears it before the extension
// loads. The scoped copies are made without that block, and each beats it
// as the scoped copy of the rule it recolored.
//
// theme: {tint: {hue, saturation}, accent, accentForeground}

export const ANIMATING_CLASS = 'ws-animating';

const BAKED_START = '/* workspace-colors: baked */';
const BAKED_END = '/* workspace-colors: end baked */';

// Below this HLS saturation a color counts as a neutral grey.
const NEUTRAL_SATURATION = 0.12;
// Above this lightness the tint fades out, so whites stay white.
const TINT_FADE_LIGHTNESS = 0.9;

const COLOR = /#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)/g;
const RULE = /([^{}]+)\{([^{}]*)\}/g;
const DECLARATION = /([\w-]+)\s*:\s*([^;]+);/g;

const isColorProperty = name =>
    name.includes('color') || name === 'background' || name === 'box-shadow';
// border and border-<side> shorthands, whose color is copied on its own.
const BORDER_SHORTHAND = /^border(-(top|right|bottom|left))?$/;
// Everything in a border shorthand that isn't its color.
const BORDER_NON_COLOR = /^(-?[\d.]+(px|em|pt|%)?|none|hidden|solid|dotted|dashed|double|groove|ridge|inset|outset)$/;

function parseColor(css) {
    if (css.startsWith('#')) {
        let digits = css.slice(1);
        if (digits.length <= 4)
            digits = [...digits].map(d => d + d).join('');
        const channels = digits.match(/../g).map(pair => parseInt(pair, 16));
        return {rgb: channels.slice(0, 3).map(c => c / 255), alpha: channels.length === 4 ? channels[3] / 255 : null};
    }
    const parts = css.slice(css.indexOf('(') + 1, -1).split(',').map(p => parseFloat(p));
    return {rgb: parts.slice(0, 3).map(c => c / 255), alpha: parts.length === 4 ? parts[3] : null};
}

function rgbToHls([r, g, b]) {
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const lightness = (max + min) / 2;
    if (max === min)
        return [0, lightness, 0];
    const delta = max - min;
    const saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min);
    const hue = max === r ? (g - b) / delta + (g < b ? 6 : 0)
        : max === g ? (b - r) / delta + 2 : (r - g) / delta + 4;
    return [hue / 6, lightness, saturation];
}

function hlsToRgb(hue, lightness, saturation) {
    if (saturation === 0)
        return [lightness, lightness, lightness];
    const q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation;
    const p = 2 * lightness - q;
    const channel = t => {
        t = (t + 1) % 1;
        if (t < 1 / 6)
            return p + (q - p) * 6 * t;
        if (t < 1 / 2)
            return q;
        if (t < 2 / 3)
            return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    };
    return [channel(hue + 1 / 3), channel(hue), channel(hue - 1 / 3)];
}

function tinted(css, tint) {
    const {rgb, alpha} = parseColor(css);
    const [, lightness, saturation] = rgbToHls(rgb);
    if (saturation > NEUTRAL_SATURATION)
        return css;
    const fade = Math.min(1, (1 - lightness) / (1 - TINT_FADE_LIGHTNESS));
    const [r, g, b] = hlsToRgb(tint.hue / 360, lightness, tint.saturation * fade)
        .map(c => Math.round(c * 255));
    return alpha === null
        ? `#${[r, g, b].map(c => c.toString(16).padStart(2, '0')).join('')}`
        : `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function recolor(value, theme) {
    return value
        .replaceAll('-st-accent-fg-color', theme.accentForeground)
        .replaceAll('-st-accent-color', theme.accent)
        .replace(COLOR, color => tinted(color, theme.tint));
}

function splitTopLevel(text, separator) {
    const parts = [];
    let depth = 0;
    let current = '';
    for (const char of text) {
        depth += (char === '(') - (char === ')');
        if (separator.test(char) && depth === 0) {
            parts.push(current);
            current = '';
        } else {
            current += char;
        }
    }
    return [...parts, current].map(p => p.trim()).filter(Boolean);
}

// [property, value] of the color a declaration sets, if any.
function colorDeclaration(property, value) {
    if (value.includes('url('))
        return null;
    if (isColorProperty(property))
        return [property, value];
    if (!BORDER_SHORTHAND.test(property))
        return null;
    const color = splitTopLevel(value, /\s/).find(token => !BORDER_NON_COLOR.test(token));
    return color ? [`${property}-color`, color] : null;
}

function splitSelectors(selectors) {
    return splitTopLevel(selectors, /,/);
}

// Rules recolored for theme, each selector prefixed by scope.
function* recoloredRules(css, scope, theme) {
    for (const [, selectors, body] of css.matchAll(RULE)) {
        const declarations = [...body.matchAll(DECLARATION)]
            .map(([, property, value]) => colorDeclaration(property, value.trim()))
            .filter(Boolean)
            .map(([property, value]) => `  ${property}: ${recolor(value, theme)};`);
        // `stage` is the root, outside any scope.
        const scoped = splitSelectors(selectors)
            .filter(selector => !selector.startsWith('stage'))
            .map(selector => `${scope}${selector}`);
        if (declarations.length && scoped.length)
            yield `${scoped.join(',\n')} {\n${declarations.join('\n')}\n}\n`;
    }
}

// While a theme change is in flight, every widget crossfades to its new
// colors; otherwise their own transitions (hover etc.) are kept. Widgets that
// set their own duration keep it.
function animatingRule(durationMs) {
    return `.${ANIMATING_CLASS} * {\n  transition-duration: ${durationMs}ms;\n}\n`;
}

function withoutBaked(css) {
    const start = css.indexOf(BAKED_START);
    const end = css.indexOf(BAKED_END, start);
    return start < 0 || end < 0 ? css : css.slice(0, start) + css.slice(end + BAKED_END.length);
}

function plain(stylesheets) {
    return stylesheets.map(css => withoutBaked(css).replace(/\/\*[\s\S]*?\*\//g, ''));
}

// stylesheets: CSS texts in cascade order; themes: {name: theme}.
export function scopedStylesheet(stylesheets, themes, transitionMs) {
    const sources = plain(stylesheets);
    return Object.entries(themes)
        .flatMap(([name, theme]) => sources.flatMap(css => [...recoloredRules(css, `.ws-${name} `, theme)]))
        .concat(animatingRule(transitionMs))
        .join('');
}

// The block baked into a stylesheet: its recolored copy for theme, then
// extra rules of the caller's.
export function bakedStylesheet(stylesheets, theme, extra) {
    const rules = plain(stylesheets).flatMap(css => [...recoloredRules(css, '', theme)]);
    return [`\n${BAKED_START}\n`, ...rules, extra, `${BAKED_END}\n`].join('');
}
