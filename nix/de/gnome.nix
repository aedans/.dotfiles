{ pkgs, ... }:
let
  codexbar = pkgs.callPackage ../pkgs/codexbar.nix { };
  colloidIcons = pkgs.callPackage ../pkgs/colloid-icons.nix { };
  # !!! OPTIMIZE ME, AND REVISIT ON GNOME 51 !!!
  # Blur my Shell blurs live, every frame, behind every window (only sidebars
  # let it show; see workspace-colors' stylesheets.nix), and the paint-below
  # patch stops mutter from skipping what's hidden behind those windows.
  # That's measurably more CPU in the VM when dragging windows and switching
  # workspaces. On GNOME 51 (NixOS 26.11):
  # - Drop Blur my Shell's application blur, the paint-below patch and probably
  #   gtk-module/sidebars.c: GTK 4.24 asks mutter to blur just the sidebar
  #   (ext-background-effect-v1) from CSS (backdrop-filter: blur()).
  # - With GNOME blurring popups too (it doesn't yet), drop Blur my Shell: the
  #   top bar and dock show pre-blurred wallpapers (see workspace-colors'
  #   wallpaperStrip.js).
  # - Check that the rounded blur library still builds against mutter 51.
  roundedBlur = pkgs.callPackage ../pkgs/gnome-rounded-blur.nix { };
  # v78 (nixpkgs has 72) blurs menus, notifications and OSDs, and still supports
  # GNOME 50. The patch keeps mutter painting below the windows it blurs behind.
  blurMyShell = pkgs.gnomeExtensions.blur-my-shell.overrideAttrs (old: {
    version = "78";
    src = pkgs.fetchzip {
      url = "https://extensions.gnome.org/extension-data/blur-my-shellaunetx.v78.shell-extension.zip";
      hash = "sha256-HlaJCzOdjs7L/36tr54SEvulyqynNm0teatftZlpM+8=";
      stripRoot = false;
    };
    patches = (old.patches or [ ]) ++ [ ../pkgs/blur-my-shell-paint-below.patch ];
  });
  # Show every provider stacked in the menu instead of one tab at a time.
  codexbarExtension = pkgs.gnomeExtensions.codexbar.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../pkgs/codexbar-extension-stacked.patch ];
  });
in
{
  imports = [ ./shell-theme.nix ./workspace-colors.nix ./login-background.nix ];

  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    # Rounds Blur my Shell's dynamic blur.
    desktopManager.gnome.sessionPath = [ roundedBlur ];
  };

  environment.gnome.excludePackages = (with pkgs; [
    gnome-text-editor
    gnome-tour
    gnome-console
    epiphany
    seahorse
  ]);

  users.users.hans.packages = with pkgs; [
    ptyxis
    gnome-tweaks
    gnome-connections
    apostrophe
    colloidIcons
    gnomeExtensions.auto-move-windows
    gnomeExtensions.caffeine
    gnomeExtensions.user-themes
    gnomeExtensions.just-perfection
    gnomeExtensions.dash-to-dock
    blurMyShell
    gnomeExtensions.vitals
    gnomeExtensions.appindicator
    gnomeExtensions.gsconnect
    gnomeExtensions.tailscale-status
    codexbarExtension
    codexbar
  ];

  # GTK 3 only knows Adwaita-dark as an installed theme; without it, apps that
  # read the GTK theme instead of the portal (Electron under X11) see light.
  environment.systemPackages = [ pkgs.gnome-themes-extra ];

  # The CodexBar extension only probes fixed paths for its CLI, not PATH.
  home-manager.users.hans.home.file.".local/bin/codexbar".source =
    "${codexbar}/bin/codexbar";
}
