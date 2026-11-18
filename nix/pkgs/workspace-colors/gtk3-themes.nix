# GTK 3's Adwaita has no color variables: its colors are compiled into the
# stylesheet from a few base colors (theme/Adwaita/_colors.scss). So each theme
# (see themes.nix) gets its own dark Adwaita, compiled from the GTK 3 sources
# with the theme's colors as the base, and scoped to its ws-<theme> windows
# (see scope-css.py), in themes.css. The GTK module loads them below
# applications' own stylesheets, where they replace the desktop's theme in
# themed windows. fade.css has the transitions for theme changes (faded, a
# transition-property list) on the nodes Adwaita gives a text color.
{ lib, runCommand, writeText, sassc, python3, gtk3, themes, faded }:
let
  # Adwaita's base colors; everything else derives from them.
  baseColors = { ui, ... }: {
    bg_color = ui.window;
    fg_color = ui.text;
    base_color = ui.view;
    text_color = ui.text;
    selected_bg_color = ui.accent;
    selected_fg_color = ui.accentForeground;
    borders_color = ui.border;
    link_color = ui.accentText;
    headerbar_color = ui.raised;
    menu_color = ui.raised;
    popover_bg_color = ui.raised;
    popover_hover_color = ui.hover;
    sidebar_bg_color = ui.sidebar;
  };
  names = lib.attrNames (baseColors (lib.head (lib.attrValues themes)));
  definition = "^\\$(${lib.concatStringsSep "|" names}):";

  # Adwaita fills headerbars with the window color darkened, not
  # $headerbar_color; this fills them with it, as libadwaita does. Dark
  # Adwaita's fill is a gradient 4% to 6% lighter than the color it's given.
  headerbarFill = "@include headerbar_fill(darken($bg_color, 10%));";
  ownHeaderbarFill = "@include headerbar_fill(darken($headerbar_color, 5%));";

  compile = name: theme: ''
    cp -r adwaita ${name}
    chmod -R u+w ${name}
    { cat ${writeText "${name}-colors.scss" (lib.concatStrings
        (lib.mapAttrsToList (var: color: "\$${var}: ${color};\n") (baseColors theme)))}
      grep -vE '${definition}' adwaita/_colors.scss
    } > ${name}/_colors.scss
    sassc -t compact ${name}/gtk-contained-dark.scss > ${name}.css
    python3 ${./scope-css.py} theme ws-${name} resource:///org/gtk/libgtk/theme/Adwaita \
      < ${name}.css >> $out/themes.css
  '';
in
runCommand "workspace-themes-gtk3-adwaita" {
  nativeBuildInputs = [ sassc (python3.withPackages (p: [ p.tinycss2 ])) ];
} ''
  tar -xf ${gtk3.src} --wildcards '*/gtk/theme/Adwaita'
  mv */gtk/theme/Adwaita adwaita
  # Each base color is defined once; a renamed one would silently keep
  # Adwaita's.
  [ $(grep -cE '${definition}' adwaita/_colors.scss) = ${toString (lib.length names)} ]
  substituteInPlace adwaita/_common.scss --replace-fail '${headerbarFill}' '${ownHeaderbarFill}'
  mkdir $out
  ${lib.concatStrings (lib.mapAttrsToList compile themes)}
  # Every theme gives color to the same nodes.
  python3 ${./scope-css.py} fade ws-animating '${faded}' < ${lib.head (lib.attrNames themes)}.css > $out/fade.css
''
