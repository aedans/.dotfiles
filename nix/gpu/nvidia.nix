{ config, pkgs-unstable, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;

    # Saves full VRAM on suspend; fixes graphical corruption or crashes after wake.
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # Open kernel modules — recommended for Turing (RTX 20/GTX 16) and newer.
    # Also enables kernelSuspendNotifier automatically on 595+.
    open = true;

    nvidiaSettings = true;

    package = (pkgs-unstable.linuxKernel.packagesFor config.boot.kernelPackages.kernel).nvidiaPackages.stable;
  };

  hardware.nvidia-container-toolkit.enable = true;
}