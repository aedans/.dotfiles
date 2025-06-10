{ config, pkgs, lib, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
      <home-manager/nixos> 
      ./de/gnome.nix
    ];

  nix.settings.experimental-features = [ "flakes" "nix-command" ];

  programs.fish.enable = true;

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  virtualisation.docker.enable = true;

  # virtualisation.vmware.host.enable = true;

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.addNetworkInterface = false;
  users.extraGroups.vboxusers.members = [ "hans" ];

  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.kernelParams = [ "kvm.enable_virt_at_load=0" ];

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.syncthing = {
    enable = true;
    user = "hans";
    dataDir = "/home/hans/Sync";    # Default folder for new synced folders
    configDir = "/home/hans/.config/syncthing";   # Folder for Syncthing's settings and keys
  };

  # Enable OpenGL
  hardware.graphics.enable = true;

  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound with pipewire.
  # hardware.pulseaudio.enable = true;
  #security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.ollama = {
    enable = true;
    # loadModels = [ "llama3.1:8b" "qwen2.5-coder:1.5b-base" "nomic-embed-text:latest"];
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-sdk-wrapped-6.0.428"
    "dotnet-sdk-6.0.428"
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.hans = {
    isNormalUser = true;
    description = "Hans";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.fish;
    packages = with pkgs; [
      firefox
    #  thunderbird
      vscode
      jetbrains.idea-community
      discord
      keepassxc
      slack
      git
      gh
      commitizen
      azure-cli
      terraform
      python3
      teams-for-linux
      lutris
      prismlauncher
      lynx
      jdk21
      libreoffice
      dolphin-emu
      azure-functions-core-tools
      postman
      icu
      pavucontrol
      lsof
    ];
  };

  home-manager.users.hans = {
    # The state version is required and should stay at the version you
    # originally installed.
    home.stateVersion = "24.11";
  };

  environment.sessionVariables = with pkgs; {
    LD_LIBRARY_PATH = lib.makeLibraryPath [
      libglvnd
      pulseaudio
    ];
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    icu
  ];

  programs.java = { 
    enable = true; 
    package = pkgs.jdk21;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
  systemd.services."docker".wantedBy = lib.mkForce [ ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    nodejs
    wineWowPackages.stable
    winetricks
    rclone
  ];

  nix.gc = {
    automatic = true;
    randomizedDelaySec = "14m";
    options = "--delete-older-than 14d";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
