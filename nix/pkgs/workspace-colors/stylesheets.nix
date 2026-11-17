# The GTK hook's stylesheets and terminal palettes, generated from themes (see
# themes.nix). Windows without a theme (e.g. on all workspaces) wear the
# default theme's colors.
{ lib, themes, default }:
let
  inherit (lib) concatStrings mapAttrsToList;
  forThemes = f: concatStrings (mapAttrsToList f themes);

  # libadwaita's colors are variables, so a GTK 4 theme just sets them.
  adwaitaVariables = { ui, ... }: ''
    --accent-bg-color: ${ui.accent};
    --accent-fg-color: ${ui.accentForeground};
    --accent-color: ${ui.accentText};
    --window-bg-color: ${ui.window};
    --window-fg-color: ${ui.text};
    --view-bg-color: ${ui.view};
    --view-fg-color: ${ui.text};
    --headerbar-bg-color: ${ui.raised};
    --headerbar-fg-color: ${ui.text};
    --headerbar-backdrop-color: ${ui.window};
    --sidebar-bg-color: ${ui.sidebar};
    --sidebar-fg-color: ${ui.text};
    --sidebar-backdrop-color: ${ui.window};
    --card-bg-color: alpha(${ui.text}, 0.05);
    --popover-bg-color: ${ui.raised};
    --popover-fg-color: ${ui.text};
    --dialog-bg-color: ${ui.raised};
    --dialog-fg-color: ${ui.text};
  '';

  # Every theme lists the same filter functions, so GTK can interpolate them.
  iconFilter = { icons, ... }:
    "drop-shadow(0px 1px 1px rgba(0, 0, 0, 0.3)) sepia(${toString icons.sepia}) "
    + "saturate(${toString icons.saturate}) hue-rotate(${toString icons.hueRotate}deg)";

  gtk4 = ''
    window {
    ${adwaitaVariables themes.${default}}}
  '' + forThemes (name: theme: ''

    window.ws-${name} {
    ${adwaitaVariables theme}}

    /* Nautilus's file icons are full-color images; thumbnails share the node
     * but carry .thumbnail and are left alone. */
    window.ws-${name} .view .nautilus-image:not(.thumbnail) {
      filter: ${iconFilter theme};
    }
  '') + ''

    /* Ptyxis colors its window from the terminal palette with concrete colors,
     * not libadwaita's variables; this stylesheet's priority is above Ptyxis's,
     * so these put the theme's variables back. */
    window.ws-themed .window-contents > revealer windowhandle,
    window.ws-themed .window-contents revealer.raised.top-bar,
    window.ws-themed .window-contents toolbarview.overview {
      background-color: var(--headerbar-bg-color);
      color: var(--headerbar-fg-color);
    }

    window.ws-themed:backdrop .window-contents revealer > windowhandle {
      background-color: var(--headerbar-backdrop-color);
      color: var(--headerbar-fg-color);
    }

    window.ws-themed .window-contents popover > contents,
    window.ws-themed .window-contents popover > arrow {
      background-color: var(--popover-bg-color);
      color: var(--popover-fg-color);
    }

    /* Only while a theme change is in flight, so hover effects keep their speed. */
    window.ws-animating,
    window.ws-animating * {
      transition-property: background-color, color, border-color, outline-color, box-shadow, filter;
      transition-duration: 400ms;
      transition-timing-function: ease-in-out;
    }
  '';

  # GTK 3's Adwaita has no color variables, so the common widgets are restyled
  # directly. Everything is a flat background-color, which GTK interpolates;
  # gradients and image() backgrounds would jump at the end of the transition
  # instead. Selectors name only the class: applications may rename their
  # window's node, and a GTK 3 menu's window carries the class of the window
  # it belongs to. Unthemed GTK 3 windows keep the desktop's GTK theme.
  gtk3Theme = name: { ui, ... }: let n = ".ws-${name}"; in ''

    ${n},
    ${n}.background {
      background-color: ${ui.window};
      color: ${ui.text};
    }
    ${n} headerbar {
      background-image: none;
      background-color: ${ui.raised};
      border-color: ${ui.border};
      box-shadow: inset 0 1px alpha(${ui.text}, 0.07);
    }
    ${n} headerbar:backdrop {
      background-color: ${ui.window};
    }
    ${n} button {
      background-image: none;
      background-color: ${ui.button};
      border-color: ${ui.border};
      box-shadow: none;
    }
    ${n} button:hover {
      background-color: ${ui.hover};
    }
    ${n} button:active,
    ${n} button:checked {
      background-color: ${ui.window};
    }
    ${n} button:backdrop {
      background-color: ${ui.raised};
    }
    ${n} button.flat,
    ${n} button.flat:backdrop {
      background-color: transparent;
      border-color: transparent;
    }
    ${n} button.flat:hover {
      background-color: ${ui.hover};
    }
    ${n} button.suggested-action {
      background-color: ${ui.accent};
      color: ${ui.accentForeground};
    }
    ${n} entry {
      background-image: none;
      background-color: ${ui.view};
      border-color: ${ui.border};
      color: ${ui.text};
    }
    ${n} .view,
    ${n} iconview,
    ${n} treeview,
    ${n} textview text,
    ${n} list {
      background-color: ${ui.view};
      color: ${ui.text};
    }
    ${n} .sidebar,
    ${n} .sidebar list,
    ${n} placessidebar list,
    ${n} stacksidebar list {
      background-color: ${ui.sidebar};
    }
    ${n} .view:selected,
    ${n} treeview:selected,
    ${n} list row:selected,
    ${n} menu menuitem:hover,
    ${n} .menu menuitem:hover {
      background-color: ${ui.accent};
      color: ${ui.accentForeground};
    }
    ${n} popover.background,
    ${n} menu,
    ${n} .menu,
    ${n} .context-menu {
      background-color: ${ui.raised};
      border-color: ${ui.border};
      color: ${ui.text};
    }
    ${n} notebook > header {
      background-color: ${ui.window};
      border-color: ${ui.border};
    }
    ${n} notebook > header.top > tabs > tab:checked {
      box-shadow: inset 0 -4px ${ui.accent};
    }
  '';

  gtk3 = forThemes gtk3Theme + ''

    /* Only while a theme change is in flight, so hover effects keep their speed. */
    .ws-animating,
    .ws-animating * {
      transition-property: background-color, color, border-color, box-shadow;
      transition-duration: 400ms;
      transition-timing-function: ease-in-out;
    }
  '';
in
{
  inherit gtk4 gtk3;
  terminalPalettes = lib.mapAttrs (name: theme: theme.terminal) themes;
}
