# A color theme per workspace (see nix/pkgs/workspace-colors): the shell
# through its extension, GTK applications through a GTK module loaded into
# each of them, and the cursor theme's accent through mutter. Applications that aren't GTK's (Firefox, VS Code, games) keep
# their own look; their dialogs follow the workspace. The session's shell runs
# in a mode of its own whose stylesheet has the first workspace's colors, so
# it starts in them. Try changes in the VM first (see nix/vm.nix).
{ pkgs, ... }:
let
  dir = ../pkgs/workspace-colors;
  themes = import (dir + "/themes.nix");
  cursors = pkgs.callPackage ../pkgs/future-cursors.nix { };
  extension = pkgs.callPackage dir {
    inherit themes;
    cursorAccent = cursors.accent;
    workspaces = [ "catppuccin" "nord" "gruvbox" "everforest" ];
  };
  stylesheets = import (dir + "/stylesheets.nix") {
    inherit (pkgs) lib;
    inherit themes;
    default = "nord";
  };
  gtk3Themes = pkgs.callPackage (dir + "/gtk3-themes.nix") {
    inherit themes;
    faded = stylesheets.faded.gtk3;
  };
  gtk4Fade = pkgs.callPackage (dir + "/gtk4-fade.nix") { faded = stylesheets.faded.gtk4; };
  gtkModule = pkgs.callPackage (dir + "/gtk-module") {
    css = pkgs.concatText "workspace-themes-gtk4.css" [
      (pkgs.writeText "workspace-colors-gtk4.css" stylesheets.gtk4)
      "${gtk4Fade}/fade.css"
    ];
    gtk3Css = pkgs.concatText "workspace-themes-gtk3.css" [
      (pkgs.writeText "workspace-fade-gtk3.css" stylesheets.gtk3)
      "${gtk3Themes}/fade.css"
    ];
    gtk3Themes = "${gtk3Themes}/themes.css";
    inherit (stylesheets) terminalPalettes;
  };
  sessionMode = pkgs.callPackage (dir + "/session-mode.nix") { inherit extension; };
in
{
  # St's tint, per-workspace backgrounds and recolored cursors, which the
  # extension builds on.
  nixpkgs.overlays = [
    (final: prev: {
      mutter = prev.mutter.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ (dir + "/patches/cursor-recolor.patch") ];
      });
      gnome-shell = prev.gnome-shell.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (dir + "/patches/st-tint.patch")
          (dir + "/patches/workspace-backgrounds.patch")
        ];
      });
    })
  ];
  # GTK 4 dropped GTK 3's GTK_MODULES, which loads the GTK module; the patch
  # puts it back. It's grafted into the system rather than rebuilt from it, so
  # nothing that uses GTK 4 is rebuilt; the patch keeps GTK 4's ABI.
  system.replaceDependencies.replacements = [{
    oldDependency = pkgs.gtk4;
    newDependency = pkgs.gtk4.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ (dir + "/patches/gtk4-modules.patch") ];
    });
  }];

  users.users.hans.packages = [ extension cursors ];
  # GTK finds the module through GTK_PATH, which covers the system profile.
  environment.systemPackages = [ sessionMode gtkModule ];
  environment.sessionVariables.GTK_MODULES = [ gtkModule.moduleName ];
  # The session's shell; the greeter's is org.gnome.Shell@gdm.
  systemd.user.units."org.gnome.Shell@user.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      ExecStart=
      ExecStart=${pkgs.gnome-shell}/bin/gnome-shell --mode=${sessionMode.modeName}
    '';
  };
}
