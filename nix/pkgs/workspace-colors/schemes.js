// schemes.json: one scheme per workspace; workspaces past the end wrap
// around. Only panel and dock are required.
//   panel, dock, background    CSS colors
//   image     wallpaper crops, one per screen shape: [{aspect, file}]; each
//             monitor shows the closest, over the background color
//   cursor    the color the cursor theme's accent takes (see cursor.js)
//   theme     names a theme: the ws-<theme> class given to the shell (see
//             stylesheet.css) and to windows of applications running the GTK
//             module

export function readSchemes(dir) {
    const [, bytes] = dir.get_child('schemes.json').load_contents(null);
    return JSON.parse(new TextDecoder().decode(bytes));
}

export function schemeAt(schemes, index) {
    return schemes[index % schemes.length];
}

// A field's value per scheme, or null unless every scheme sets it, so that no
// workspace is left showing a stale value.
export function fieldOfAll(schemes, field) {
    return schemes.every(s => s[field] !== undefined) ? schemes.map(s => s[field]) : null;
}
