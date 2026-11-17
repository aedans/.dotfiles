# The login screen's background: Raja's Toothless above the clouds. GDM's
# greeter draws no wallpaper, only the shell theme's #lockDialogGroup, and the
# shell reads its theme from a resource compiled into gnome-shell, so the art
# is added to that resource. The image is dimmed so the login's white text
# stays readable over the clouds. The lock screen draws the session's own
# wallpaper above this, so it only shows at login.
{ pkgs, ... }:
let
  image = pkgs.runCommand "login-background.jpg" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick ${../../.config/background} -resize '3840x>' -fill black -colorize 40% -quality 90 $out
  '';
  css = ''
    #lockDialogGroup {
      background: #222226 url("resource:///org/gnome/shell/theme/login-background.jpg");
      background-size: cover;
      background-position: center;
    }
  '';
in
{
  nixpkgs.overlays = [
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
          cp ${image} $dir/login-background.jpg
          for variant in dark light; do
            cat >> $dir/gnome-shell-$variant.css <<'EOF'
          ${css}
          EOF
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
