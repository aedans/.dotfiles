// Free of GNOME's libraries, so bake.mjs can import it at build time.

// GNOME gives each dock icon a tile in its own dock's grey, which shows as a
// square on any other dock color, and a hover highlight in a fixed lighter
// grey. Here the tile is clear and the highlight a translucent white, so it
// has the same contrast on every dock. Themes copy this after the shell's own
// rules (see shellTheme.js and bake.mjs), so it wins.
export const DOCK_STYLESHEET = `
#dash .dash-item-container .show-apps .overview-icon,
#dash .dash-item-container .overview-tile .overview-icon {
  background-color: rgba(255, 255, 255, 0);
}
#dash .dash-item-container .show-apps:hover .overview-icon,
#dash .dash-item-container .overview-tile:hover .overview-icon {
  background-color: rgba(255, 255, 255, 0.1);
}
`;
