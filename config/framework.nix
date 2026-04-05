{
  imports = [ 
    /home/hans/.dotfiles/nix/shared.nix
    /home/hans/.dotfiles/nix/boot/systemd.nix
    /home/hans/.dotfiles/nix/de/gnome.nix
  ];

  boot.kernelParams = [ "amdgpu.sg_display=0" "amdgpu.dcdebugmask=0x410" ];

  networking.hostName = "framework";
}