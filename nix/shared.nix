{ config, pkgs, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz";
in
{
  imports =
    [ # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
      (import "${home-manager}/nixos")
    ];

  nix.settings.experimental-features = [ "flakes" "nix-command" ];
  
  home-manager.useGlobalPkgs = true;  
  home-manager.users.hans = {
    home.stateVersion = "24.05";
    programs.fish.enable = true;

    dconf = {
      enable = true;

      settings = {
        "org/gnome/desktop/interface".color-scheme = "prefer-dark";

        "org/gnome/desktop/peripherals/mouse".accel-profile = "flat";

        "org/gnome/desktop/background" = {
          picture-uri = "file:///home/hans/.dotfiles/.config/1x1_#000000FF.png";
          picture-uri-dark = "file:///home/hans/.dotfiles/.config/1x1_#000000FF.png";
          primary-color = "#000000";
        };

        "org/gnome/desktop/screensaver" = {
          picture-uri = "file:///home/hans/.dotfiles/.config/1x1_#000000FF.png";
          primary-color = "#000000";
        };
        
        "org/gnome/desktop/wm/keybindings" = {
          move-to-workspace-1 = [ "<Shift><Alt>1" ];
          move-to-workspace-2 = [ "<Shift><Alt>2" ];
          move-to-workspace-3 = [ "<Shift><Alt>3" ];
          move-to-workspace-4 = [ "<Shift><Alt>4" ];

          switch-to-workspace-1 = [ "<Alt>1" ];
          switch-to-workspace-2 = [ "<Alt>2" ];
          switch-to-workspace-3 = [ "<Alt>3" ];
          switch-to-workspace-4 = [ "<Alt>4" ];
        };

        "org/gnome/shell".favorite-apps = [
          "firefox.desktop"
          "org.gnome.Nautilus.desktop"
          "discord.desktop"
          "slack.desktop"
          "codium.desktop"
          "teams-for-linux.desktop"
          "steam.desktop"
        ];
      };
    };

    programs.vscode = {
      enable = true;

      extensions = (with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
      ]);
    };
  };

  programs.fish.enable = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  virtualisation.docker.enable = true;

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "hans" ];

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

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.excludePackages = [ pkgs.xterm ];

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Enable OpenGL
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

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
      discord
      keepassxc
      slack
      git
      gh
      azure-functions-core-tools
      commitizen
      azure-cli
      terraform
      python3
      teams-for-linux
      lutris
      gnome3.gnome-tweaks
      prismlauncher
      lynx
      jdk17
      jdk21
      libreoffice
    ];
  };

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  system.autoUpgrade.enable = true;
  # system.autoUpgrade.allowReboot = true;

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
  system.stateVersion = "24.05"; # Did you read the comment?

}
