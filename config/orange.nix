{ pkgs, ... }:

{
  imports = [
    /home/hans/.dotfiles/nix/shared.nix
    /home/hans/.dotfiles/nix/boot/systemd.nix
    /home/hans/.dotfiles/nix/gpu/nvidia.nix
    # /home/hans/.dotfiles/nix/gpu/llama.nix
    /home/hans/.dotfiles/nix/de/gnome.nix
    /home/hans/.dotfiles/nix/remote/rdp.nix
    # /home/hans/.dotfiles/nix/backup/usb.nix
  ];

  networking.hostName = "orange";

  # Shrink ext4's root-reserved space on / from the default 5% (~42G) to 1%
  systemd.services.root-reserved-blocks = {
    description = "Set ext4 reserved blocks on / to 1%";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.e2fsprogs}/bin/tune2fs -m 1 /dev/disk/by-uuid/893f3f0b-b74f-4e3b-a25b-b46c5ebe449d";
    };
  };
}
