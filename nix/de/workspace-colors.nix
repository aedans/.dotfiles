# A color theme per workspace (see nix/pkgs/workspace-colors): the shell
# through its extension, GNOME's GTK applications through a hook preloaded
# into the session. Applications that aren't GTK's (Firefox, VS Code, games)
# keep their own look; their dialogs follow the workspace. The session's shell
# runs in a mode of its own whose stylesheet has the first workspace's colors
# baked in, so it starts in them. Try changes in the VM first (see
# nix/vm.nix).
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
  sessionMode = pkgs.callPackage ../pkgs/workspace-colors/session-mode.nix { inherit extension; };
in
{
  users.users.hans.packages = [ extension ];
  environment.systemPackages = [ sessionMode ];
  # The session's shell; the greeter's is org.gnome.Shell@gdm.
  systemd.user.units."org.gnome.Shell@user.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      ExecStart=
      ExecStart=${pkgs.gnome-shell}/bin/gnome-shell --mode=${sessionMode.modeName}
    '';
  };
  environment.sessionVariables.LD_PRELOAD = "${gtkHook}/lib/workspace-theme/preload.so";
}
