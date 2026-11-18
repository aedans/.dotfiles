# Additions to the shell's own theme, which gnome-shell compiles into a
# resource: the greeter's only theme, and the session's base stylesheet.
{ config, lib, ... }:
let
  cfg = config.shellTheme;
in
{
  options.shellTheme = {
    files = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Files added to the theme, as resource:///org/gnome/shell/theme/<name>.";
    };
    css = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "CSS appended to each of the theme's stylesheets.";
    };
  };

  config.nixpkgs.overlays = [
    (final: prev: {
      gnome-shell = prev.gnome-shell.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          resource=$out/share/gnome-shell/gnome-shell-theme.gresource
          theme=$(mktemp -d)
          for file in $(${final.buildPackages.glib.dev}/bin/gresource list $resource); do
            mkdir -p $theme/$(dirname $file)
            ${final.buildPackages.glib.dev}/bin/gresource extract $resource $file > $theme/$file
          done
          dir=$theme/org/gnome/shell/theme
          ${lib.concatStrings (lib.mapAttrsToList (name: file: ''
            cp ${file} $dir/${name}
          '') cfg.files)}
          for variant in dark light; do
            cat ${builtins.toFile "shell-theme.css" cfg.css} >> $dir/gnome-shell-$variant.css
          done
          {
            echo '<?xml version="1.0" encoding="UTF-8"?><gresources><gresource prefix="/org/gnome/shell/theme">'
            for file in $dir/*; do echo "<file>$(basename $file)</file>"; done
            echo '</gresource></gresources>'
          } > $theme/theme.gresource.xml
          ${final.buildPackages.glib.dev}/bin/glib-compile-resources \
            --sourcedir=$dir --target=$resource $theme/theme.gresource.xml
        '';
      });
    })
  ];
}
