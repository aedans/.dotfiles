{
  imports = [
    ./dconf/-org-gnome-desktop-.nix
    ./dconf/-org-gnome-mutter-.nix
    ./dconf/-org-gnome-shell-.nix 
  ];

  home.stateVersion = "24.11";

  dconf.enable = true;
}