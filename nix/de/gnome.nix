{ pkgs, ... }:
let
  codexbar = pkgs.callPackage ../pkgs/codexbar.nix { };
  # Show every provider stacked in the menu instead of one tab at a time.
  codexbarExtension = pkgs.gnomeExtensions.codexbar.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../pkgs/codexbar-extension-stacked.patch ];
  });
in
{
  imports = [ ./shell-theme.nix ./workspace-colors.nix ./login-background.nix ];

  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  environment.gnome.excludePackages = (with pkgs; [
    gnome-text-editor
    gnome-tour
    gnome-console
    epiphany
    seahorse
  ]);

  users.users.hans.packages = with pkgs; [
    ptyxis
    gnome-tweaks
    gnome-connections
    apostrophe
    gnomeExtensions.auto-move-windows
    gnomeExtensions.caffeine
    gnomeExtensions.user-themes
    gnomeExtensions.just-perfection
    gnomeExtensions.dash-to-dock
    gnomeExtensions.vitals
    gnomeExtensions.appindicator
    gnomeExtensions.gsconnect
    gnomeExtensions.tailscale-status
    codexbarExtension
    codexbar
  ];

  # GTK 3 only knows Adwaita-dark as an installed theme; without it, apps that
  # read the GTK theme instead of the portal (Electron under X11) see light.
  environment.systemPackages = [ pkgs.gnome-themes-extra ];

  # The CodexBar extension only probes fixed paths for its CLI, not PATH.
  home-manager.users.hans.home.file.".local/bin/codexbar".source =
    "${codexbar}/bin/codexbar";
}
