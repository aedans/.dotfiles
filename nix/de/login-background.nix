# The login screen's background: Raja's Toothless above the clouds. GDM's
# greeter draws no wallpaper, only the shell theme's #lockDialogGroup, so the
# art is added to the shell's theme (see shell-theme.nix). The image is dimmed
# so the login's white text stays readable over the clouds. The lock screen
# draws the session's own wallpaper above this, so it only shows at login.
{ pkgs, ... }:
let
  image = pkgs.runCommand "login-background.jpg" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick ${../../.config/background} -resize '3840x>' -fill black -colorize 40% -quality 90 $out
  '';
in
{
  shellTheme = {
    files."login-background.jpg" = image;
    css = ''
      #lockDialogGroup {
        background: #222226 url("resource:///org/gnome/shell/theme/login-background.jpg");
        background-size: cover;
        background-position: center;
      }
    '';
  };
}
