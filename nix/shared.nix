{ config, pkgs, pkgs-unstable, lib, ... }:
{
  imports = [ 
    /etc/nixos/hardware-configuration.nix
    ./de/gnome.nix
  ];

  users.extraGroups.vboxusers.members = [ "hans" ];
  users.users.hans = {
    isNormalUser = true;
    description = "Hans";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.fish;
    packages = with pkgs; [
      firefox
      chromium
      vscode
      jetbrains.idea-community
      discord
      keepassxc
      slack
      git
      gh
      python3
      teams-for-linux
      lutris
      prismlauncher
      lynx
      jdk21
      openjdk25
      libreoffice
      dolphin-emu
      postman
      icu
      ocl-icd
      intel-compute-runtime
      pavucontrol
      lsof
      ollama
      qemu
      vulkan-hdr-layer-kwin6
      imagemagick
      networkmanagerapplet
      obs-studio
    ];
  };

  environment.systemPackages = with pkgs; [
    nodejs_20
    wineWowPackages.stable
    winetricks
    rclone
  ];

  programs = {
    fish.enable = true;

    steam = {
      enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      remotePlay.openFirewall = true; 
      dedicatedServer.openFirewall = true;
      gamescopeSession = {
        enable = true;
        args = [ "--hdr-enabled" "--hdr-itm-enable" ];
      };
    };

    gamescope = {
      enable = true;
      capSysNice = true;
    };

    java = { 
      enable = true; 
      package = pkgs.jdk21;
    };

    nix-ld = {
      enable = true;
      libraries = with pkgs; [ stdenv.cc.cc icu ];
    };
  };

  services = {
    syncthing = {
      enable = true;
      user = "hans";
      dataDir = "/home/hans/Sync";
      configDir = "/home/hans/.config/syncthing";
    };

    ollama = {
      enable = true;
      # loadModels = [ "llama3.1:8b" "qwen2.5-coder:1.5b-base" "nomic-embed-text:latest"];
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };

  virtualisation = {
    virtualbox.host.enable = true;
    virtualbox.host.addNetworkInterface = false;
    docker.enable = true;
  };

  networking = {
    networkmanager.enable = true;
    # firewall = {
    #   enable = false;
    #   allowedTCPPorts = [ 25565 ];
    #   allowedUDPPorts = [  ];
    # };
  };

  hardware = {
    nvidia-container-toolkit.enable = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [ ocl-icd intel-compute-runtime ];
    };
  };

  environment.sessionVariables = with pkgs; {
    LD_LIBRARY_PATH = lib.makeLibraryPath [
      libglvnd
      pulseaudio
    ];
  };

  nix = {
    settings.experimental-features = [ "flakes" "nix-command" ];
    gc = {
      automatic = true;
      randomizedDelaySec = "14m";
      options = "--delete-older-than 90d";
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "mbedtls-2.28.10"
    ];
  };

  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  systemd.services = {
    "getty@tty1".enable = false;
    "autovt@tty1".enable = false;
    "docker".wantedBy = lib.mkForce [ ];
  };

  time.timeZone = "America/Los_Angeles";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
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
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11";
}
