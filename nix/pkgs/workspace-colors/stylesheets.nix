# The GTK module's stylesheets and terminal palettes, generated from themes (see
# themes.nix). Windows without a theme (e.g. on all workspaces) wear the
# default theme's colors.
{ lib, themes, default }:
let
  inherit (lib) concatStrings concatStringsSep mapAttrsToList;
  forThemes = f: concatStrings (mapAttrsToList f themes);

  # What fades while a theme change is in flight. Text color fades only where
  # it's set, the window here and the toolkit theme's nodes setting one (see
  # gtk3-themes.nix and gtk4-fade.nix); nodes that inherit it follow.
  faded = {
    gtk3 = [ "background-color" "background-image" "color" "border-color" "box-shadow" ];
    gtk4 = [ "background-color" "color" "border-color" "outline-color" "box-shadow" "filter" ];
  };
  transitionProperty = properties: "transition-property: ${concatStringsSep ", " properties};";
  withoutColor = lib.remove "color";

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

    /* Apostrophe's editor is a GtkSourceView whose style scheme colors its text
     * with concrete colors; these put the theme's view colors back. */
    window .apostrophe-editor,
    window .apostrophe-editor > text {
      background-color: var(--view-bg-color);
      color: var(--view-fg-color);
    }

    /* Only while a theme change is in flight, so hover effects keep their speed.
     * As long as the workspace slide, and eased like it (ease-out cubic). */
    window.ws-animating,
    window.ws-animating * {
      ${transitionProperty (withoutColor faded.gtk4)}
      transition-duration: 250ms;
      transition-timing-function: cubic-bezier(0.33, 1, 0.68, 1);
    }
    window.ws-animating {
      ${transitionProperty faded.gtk4}
    }

    /* A first theme (or none) applies at once, buttons included. */
    window.ws-settling,
    window.ws-settling * {
      transition: none;
    }
  '';

  # GTK 3's themes are whole stylesheets (see gtk3-themes.nix); this only fades
  # between them.
  gtk3 = ''
    /* Only while a theme change is in flight, so hover effects keep their speed.
     * As long as the workspace slide, and eased like it (ease-out cubic). */
    .ws-animating,
    .ws-animating * {
      ${transitionProperty (withoutColor faded.gtk3)}
      transition-duration: 250ms;
      transition-timing-function: cubic-bezier(0.33, 1, 0.68, 1);
    }
    .ws-animating {
      ${transitionProperty faded.gtk3}
    }

    /* A first theme (or none) applies at once, buttons included. */
    .ws-settling,
    .ws-settling * {
      transition: none;
    }
  '';
in
{
  inherit gtk4 gtk3;
  faded = lib.mapAttrs (toolkit: concatStringsSep ", ") faded;
  terminalPalettes = lib.mapAttrs (name: theme: theme.terminal) themes;
}
