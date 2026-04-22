{
  imports = [ 
    /home/hans/.dotfiles/nix/shared.nix
    /home/hans/.dotfiles/nix/boot/systemd.nix
    /home/hans/.dotfiles/nix/gpu/nvidia.nix
    /home/hans/.dotfiles/nix/gpu/llama.nix
    /home/hans/.dotfiles/nix/de/gnome.nix
    # /home/hans/.dotfiles/nix/backup/usb.nix
  ];

  networking.hostName = "orange";
}