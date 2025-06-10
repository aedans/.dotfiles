{ pkgs, ... }:
{
  services = {
    desktopManager.plasma6.enable = true;
    displayManager.sddm.enable = true;
    displayManager.sddm.wayland.enable = true;
  };

  users.users.hans.packages = with pkgs; [
    nordic
  ];
  
  home-manager.users.hans = {
    imports = [ 
      <plasma-manager/modules> 
    ];
  };
}