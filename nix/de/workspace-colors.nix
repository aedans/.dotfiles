# A color theme per workspace (see nix/pkgs/workspace-colors): the shell
# through its extension, GNOME's GTK applications through a hook preloaded
# into the session. Applications that aren't GTK's (Firefox, VS Code, games)
# keep their own look; their dialogs follow the workspace. Try changes in the
# VM first (see nix/vm.nix).
{ pkgs, ... }:
let
  themes = import ../pkgs/workspace-colors/themes.nix;
  extension = pkgs.callPackage ../pkgs/workspace-colors {
    inherit themes;
    workspaces = [ "catppuccin" "nord" "gruvbox" "everforest" ];
  };
  stylesheets = import ../pkgs/workspace-colors/stylesheets.nix {
    inherit (pkgs) lib;
    inherit themes;
    default = "nord";
  };
  gtkHook = pkgs.callPackage ../pkgs/workspace-colors/gtk-hook {
    css = pkgs.writeText "workspace-themes-gtk4.css" stylesheets.gtk4;
    gtk3Css = pkgs.writeText "workspace-themes-gtk3.css" stylesheets.gtk3;
    inherit (stylesheets) terminalPalettes;
  };
in
{
  users.users.hans.packages = [ extension ];
  environment.sessionVariables.LD_PRELOAD = "${gtkHook}/lib/workspace-theme/preload.so";
}
