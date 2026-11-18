# The shell's mode for the user session: the user mode under its own name,
# with the shell's stylesheets plus the first workspace's colors (the
# extension's startupCss), so the session starts in them before the extension
# loads. The greeter runs in its own mode, so it keeps the stock colors.
{ lib, runCommand, writeText, glib, gnome-shell, extension }:
let
  name = "workspace-colors";
  mode = builtins.toJSON { parentMode = "user"; stylesheetName = "${name}.css"; };
  startupCss = writeText "workspace-colors-startup.css" extension.startupCss;
in
runCommand "gnome-shell-mode-${name}" { passthru.modeName = name; } ''
  modes=$out/share/gnome-shell/modes
  theme=$out/share/gnome-shell/theme
  mkdir -p $modes $theme
  echo ${lib.escapeShellArg mode} > $modes/${name}.json
  resource=${gnome-shell}/share/gnome-shell/gnome-shell-theme.gresource
  for variant in dark light high-contrast; do
    ${glib.dev}/bin/gresource extract $resource /org/gnome/shell/theme/gnome-shell-$variant.css \
      > $theme/${name}-$variant.css
  done
  for variant in dark light; do
    cat ${startupCss} >> $theme/${name}-$variant.css
  done
''
