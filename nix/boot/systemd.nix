{
  boot = {
    kernelParams = [ "kvm.enable_virt_at_load=0" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
}