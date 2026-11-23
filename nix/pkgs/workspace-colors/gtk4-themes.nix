# GTK 4 applications without libadwaita (e.g. pavucontrol) wear GTK's own
# Default theme, which, like GTK 3's Adwaita, has no color variables: its
# colors are compiled into the stylesheet from a few base colors
# (gtk/theme/Default/_colors.scss). So each theme (see themes.nix) gets its own
# dark Default, compiled from the GTK 4 sources with the theme's colors as the
# base, and scoped to its ws-<theme> windows (see scope-css.py), in themes.css.
# The GTK module loads them below applications' own stylesheets, where they
# replace GTK's theme in themed windows, and only where libadwaita isn't
# loaded, since libadwaita replaces GTK's theme with its own. fade.css has the
# transitions for theme changes (faded, a transition-property list) on the
# nodes Default gives a text color.
{ lib, runCommand, writeText, sassc, python3, gtk4, themes, faded }:
let
  # Default's base colors; everything else derives from them.
  baseColors = { ui, ... }: {
    bg_color = ui.window;
    fg_color = ui.text;
    base_color = ui.view;
    text_color = ui.text;
    selected_bg_color = ui.accent;
    selected_fg_color = ui.accentForeground;
    accent_color = ui.accentText;
    borders_color = ui.border;
    link_color = ui.accentText;
    headerbar_bg_color = ui.raised;
    menu_color = ui.raised;
    sidebar_bg_color = ui.sidebar;
  };
  names = lib.attrNames (baseColors (lib.head (lib.attrValues themes)));
  definition = "^\\$(${lib.concatStringsSep "|" names}):";

  # Default fills headerbars with the window color darkened, not
  # $headerbar_bg_color; this fills them with it, as libadwaita does. Dark
  # Default's fill is a gradient 4% to 6% lighter than the color it's given.
  headerbarFill = "@include headerbar_fill(darken($bg_color, 10%));";
  ownHeaderbarFill = "@include headerbar_fill(darken($headerbar_bg_color, 5%));";

  compile = name: theme: ''
    cp -r default ${name}
    chmod -R u+w ${name}
    { cat ${writeText "${name}-colors.scss" (lib.concatStrings
        (lib.mapAttrsToList (var: color: "\$${var}: ${color};\n") (baseColors theme)))}
      grep -vE '${definition}' default/_colors.scss
    } > ${name}/_colors.scss
    sassc -t compact ${name}/Default-dark.scss > ${name}.css
    python3 ${./scope-css.py} theme ws-${name} resource:///org/gtk/libgtk/theme/Default \
      < ${name}.css >> $out/themes.css
  '';
in
runCommand "workspace-themes-gtk4-default" {
  nativeBuildInputs = [ sassc (python3.withPackages (p: [ p.tinycss2 ])) ];
} ''
  tar -xf ${gtk4.src} --wildcards '*/gtk/theme/Default'
  mv */gtk/theme/Default default
  # Each base color is defined once; a renamed one would silently keep
  # Default's.
  [ $(grep -cE '${definition}' default/_colors.scss) = ${toString (lib.length names)} ]
  substituteInPlace default/_common.scss --replace-fail '${headerbarFill}' '${ownHeaderbarFill}'
  mkdir $out
  ${lib.concatStrings (lib.mapAttrsToList compile themes)}
  # Every theme gives color to the same nodes.
  python3 ${./scope-css.py} fade ws-animating '${faded}' < ${lib.head (lib.attrNames themes)}.css > $out/fade.css
''
