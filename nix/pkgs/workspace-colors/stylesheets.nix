# The GTK module's stylesheets and terminal palettes, generated from themes (see
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

    /* Only while a theme change is in flight, so hover effects keep their speed.
     * As long as the workspace slide, and eased like it (ease-out cubic). */
    window.ws-animating,
    window.ws-animating * {
      transition-property: background-color, color, border-color, outline-color, box-shadow, filter;
      transition-duration: 250ms;
      transition-timing-function: cubic-bezier(0.33, 1, 0.68, 1);
    }
  '';

  # GTK 3's themes are whole stylesheets (see gtk3-themes.nix); this only fades
  # between them. Text color fades only where it's set, the window here and
  # Adwaita's nodes in gtk3-themes.nix's fade.css; nodes that inherit it follow.
  gtk3 = ''
    /* Only while a theme change is in flight, so hover effects keep their speed.
     * As long as the workspace slide, and eased like it (ease-out cubic). */
    .ws-animating,
    .ws-animating * {
      transition-property: background-color, background-image, border-color, box-shadow;
      transition-duration: 250ms;
      transition-timing-function: cubic-bezier(0.33, 1, 0.68, 1);
    }
    .ws-animating {
      transition-property: background-color, background-image, color, border-color, box-shadow;
    }
  '';
in
{
  inherit gtk4 gtk3;
  terminalPalettes = lib.mapAttrs (name: theme: theme.terminal) themes;
}
