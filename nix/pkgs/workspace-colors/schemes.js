// schemes.json: one scheme per workspace, every field optional; workspaces
// past the end wrap around.
//   background, panel, dock    CSS colors
//   image     wallpaper crops, one per screen shape: [{aspect, file}]; each
//             monitor shows the closest, over the background color
//   theme     names a theme: the ws-<theme> class given to the shell and to
//             windows of applications running the GTK hook

function readJson(dir, name) {
    const [, bytes] = dir.get_child(name).load_contents(null);
    return JSON.parse(new TextDecoder().decode(bytes));
}

export function readSchemes(dir) {
    return readJson(dir, 'schemes.json');
}

// themes.json: {name: theme}; see scopedCss.js.
export function readThemes(dir) {
    return readJson(dir, 'themes.json');
}

export function schemeAt(schemes, index) {
    return schemes[index % schemes.length];
}

// A field's value per scheme, or null unless every scheme sets it, so that no
// workspace is left showing a stale value.
export function fieldOfAll(schemes, field) {
    return schemes.every(s => s[field] !== undefined) ? schemes.map(s => s[field]) : null;
}
