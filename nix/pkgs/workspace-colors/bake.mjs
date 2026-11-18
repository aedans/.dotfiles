// Prints the first workspace's colors as a block to append to one of the
// shell's own stylesheets, so the shell wears them from its first frame,
// before the extension loads (see scopedCss.js). Run by Node at build time.
//   node bake.mjs <stylesheet> <extension dir>
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

import {DOCK_STYLESHEET} from './dockStylesheet.js';
import {bakedStylesheet} from './scopedCss.js';

const [stylesheet, dir] = process.argv.slice(2);
const readJson = name => JSON.parse(readFileSync(join(dir, name), 'utf8'));
const [first] = readJson('schemes.json');
const theme = first.theme === undefined ? undefined : readJson('themes.json')[first.theme];

// The top bar and the overview's background, which chrome.js paints.
const panel = first.panel ? `#panel,\n#overviewGroup {\n  background-color: ${first.panel};\n}\n` : '';
if (theme)
    process.stdout.write(bakedStylesheet([readFileSync(stylesheet, 'utf8'), DOCK_STYLESHEET], theme, panel));
