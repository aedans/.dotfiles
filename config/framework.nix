{ lib, ... }:

{
  imports = [
    /home/hans/.dotfiles/nix/shared.nix
    /home/hans/.dotfiles/nix/boot/systemd.nix
    /home/hans/.dotfiles/nix/de/gnome.nix
  ];

  boot.kernelParams = [ "amdgpu.sg_display=0" "amdgpu.dcdebugmask=0x410" ];

  networking.hostName = "framework";

  # The Goodix reader in the power button; Secrets uses it for quick unlock.
  services.fprintd.enable = true;

  # A fingerprint login gives PAM no password to unlock the login keyring with,
  # so GDM login is password-only; the lock screen, sudo and polkit keep fingerprint.
  security.pam.services.gdm-fingerprint.enable = lib.mkForce false;
}
