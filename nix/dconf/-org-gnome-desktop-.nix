# Generated via dconf2nix: https://github.com/gvolpe/dconf2nix
{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {
    "org/gnome/desktop/a11y/applications" = {
      screen-reader-enabled = false;
    };

    "org/gnome/desktop/app-folders" = {
      folder-children = [ "Utilities" "YaST" "Pardus" ];
    };

    "org/gnome/desktop/app-folders/folders/Pardus" = {
      categories = [ "X-Pardus-Apps" ];
      name = "X-Pardus-Apps.directory";
      translate = true;
    };

    "org/gnome/desktop/app-folders/folders/Utilities" = {
      apps = [ "gnome-abrt.desktop" "gnome-system-log.desktop" "nm-connection-editor.desktop" "org.gnome.baobab.desktop" "org.gnome.Connections.desktop" "org.gnome.DejaDup.desktop" "org.gnome.Dictionary.desktop" "org.gnome.DiskUtility.desktop" "org.gnome.Evince.desktop" "org.gnome.FileRoller.desktop" "org.gnome.fonts.desktop" "org.gnome.Loupe.desktop" "org.gnome.seahorse.Application.desktop" "org.gnome.tweaks.desktop" "org.gnome.Usage.desktop" "vinagre.desktop" ];
      categories = [ "X-GNOME-Utilities" ];
      name = "X-GNOME-Utilities.directory";
      translate = true;
    };

    "org/gnome/desktop/app-folders/folders/YaST" = {
      categories = [ "X-SuSE-YaST" ];
      name = "suse-yast.directory";
      translate = true;
    };

    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///home/hans/.config/background";
      picture-uri-dark = "file:///home/hans/.config/background";
      primary-color = "#3a4ba0";
      secondary-color = "#2f302f";
    };

    "org/gnome/desktop/input-sources" = {
      sources = [ (mkTuple [ "xkb" "us" ]) ];
      xkb-options = [ "terminate:ctrl_alt_bksp" ];
    };

    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-size = 24;
      cursor-theme = "Future-cursors";
      enable-animations = true;
      enable-hot-corners = true;
      font-antialiasing = "grayscale";
      font-hinting = "slight";
      font-name = "Noto Sans,  10";
      gtk-enable-primary-paste = true;
      gtk-theme = "shell-Dark-Nord";
      icon-theme = "Nordzy-dark";
      scaling-factor = mkUint32 1;
      text-scaling-factor = 1.0;
      toolbar-style = "text";
      toolkit-accessibility = false;
    };

    "org/gnome/desktop/notifications" = {
      show-banners = true;
    };

    "org/gnome/desktop/peripherals/keyboard" = {
      numlock-state = true;
      repeat = true;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      accel-profile = "flat";
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      two-finger-scrolling-enabled = true;
    };

    "org/gnome/desktop/privacy" = {
      old-files-age = mkUint32 30;
      recent-files-max-age = -1;
    };

    "org/gnome/desktop/screensaver" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///nix/store/3r0z34ppzfmg8hgnmmn8aw4bv0a7an81-simple-blue-2016-02-19/share/backgrounds/nixos/nix-wallpaper-simple-blue.png";
      primary-color = "#3a4ba0";
      secondary-color = "#2f302f";
    };

    "org/gnome/desktop/search-providers" = {
      sort-order = [ "org.gnome.Contacts.desktop" "org.gnome.Documents.desktop" "org.gnome.Nautilus.desktop" ];
    };

    "org/gnome/desktop/session" = {
      idle-delay = mkUint32 0;
    };

    "org/gnome/desktop/sound" = {
      allow-volume-above-100-percent = true;
    };

    "org/gnome/desktop/wm/keybindings" = {
      move-to-workspace-1 = [ "<Shift><Alt>1" ];
      move-to-workspace-2 = [ "<Shift><Alt>2" ];
      move-to-workspace-3 = [ "<Shift><Alt>3" ];
      move-to-workspace-4 = [ "<Shift><Alt>4" ];
      switch-applications = [];
      switch-applications-backward = [];
      switch-to-workspace-1 = [ "<Alt>1" ];
      switch-to-workspace-2 = [ "<Alt>2" ];
      switch-to-workspace-3 = [ "<Alt>3" ];
      switch-to-workspace-4 = [ "<Alt>4" ];
      switch-windows = [ "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Alt>Tab" ];
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
      theme = "Nordic";
    };

  };
}