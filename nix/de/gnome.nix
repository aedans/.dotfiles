{ pkgs, ... }:
{
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
    gnome-terminal
    gnome-tweaks
    gnomeExtensions.auto-move-windows
    gnomeExtensions.user-themes
    gnomeExtensions.just-perfection
    gnomeExtensions.dash-to-dock
    gnomeExtensions.vitals
    gnomeExtensions.appindicator
    gnomeExtensions.gsconnect
  ];
}