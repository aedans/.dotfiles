# Generated via dconf2nix: https://github.com/gvolpe/dconf2nix
{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      disabled-extensions = [ "system-monitor@gnome-shell-extensions.gcampax.github.com" "native-window-placement@gnome-shell-extensions.gcampax.github.com" "windowsNavigator@gnome-shell-extensions.gcampax.github.com" "workspace-indicator@gnome-shell-extensions.gcampax.github.com" "places-menu@gnome-shell-extensions.gcampax.github.com" "drive-menu@gnome-shell-extensions.gcampax.github.com" "window-list@gnome-shell-extensions.gcampax.github.com" "apps-menu@gnome-shell-extensions.gcampax.github.com" ];
      enabled-extensions = [ "user-theme@gnome-shell-extensions.gcampax.github.com" "just-perfection-desktop@just-perfection" "dash-to-dock@micxgx.gmail.com" "auto-move-windows@gnome-shell-extensions.gcampax.github.com" "Vitals@CoreCoding.com" "appindicatorsupport@rgcjonas.gmail.com" ];
      favorite-apps = [ "firefox.desktop" "org.gnome.Nautilus.desktop" "discord.desktop" "code.desktop" "idea-community.desktop" "steam.desktop" ];
      last-selected-power-profile = "power-saver";
      welcome-dialog-last-shown-version = "47.2";
    };

    "org/gnome/shell/app-switcher" = {
      current-workspace-only = false;
    };

    "org/gnome/shell/extensions/appindicator" = {
      icon-size = 20;
      tray-pos = "right";
    };

    "org/gnome/shell/extensions/auto-move-windows" = {
      application-list = [ "firefox.desktop:1" "discord.desktop:1" "slack.desktop:1" "code.desktop:2" "idea-community.desktop:2" "teams-for-linux.desktop:1" "steam.desktop:3" ];
    };

    "org/gnome/shell/extensions/custom-accent-colors" = {
      accent-color = "blue";
      theme-flatpak = false;
      theme-gtk3 = false;
      theme-shell = false;
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      apply-custom-theme = false;
      apply-glossy-effect = false;
      background-color = "rgb(32,36,44)";
      background-opacity = 1.0;
      custom-background-color = true;
      custom-theme-customize-running-dots = false;
      custom-theme-shrink = false;
      dash-max-icon-size = 64;
      disable-overview-on-startup = false;
      dock-position = "BOTTOM";
      extend-height = false;
      height-fraction = 0.9;
      hide-tooltip = true;
      icon-size-fixed = false;
      intellihide-mode = "ALL_WINDOWS";
      isolate-monitors = false;
      isolate-workspaces = false;
      max-alpha = 0.8;
      preferred-monitor = -2;
      preview-size-scale = 0.0;
      running-indicator-dominant-color = true;
      running-indicator-style = "DASHES";
      scroll-to-focused-application = true;
      show-favorites = true;
      show-mounts = false;
      show-running = true;
      show-show-apps-button = false;
      show-trash = false;
      show-windows-preview = true;
      transparency-mode = "FIXED";
      unity-backlit-items = false;
      workspace-agnostic-urgent-windows = true;
    };

    "org/gnome/shell/extensions/just-perfection" = {
      accessibility-menu = false;
      alt-tab-icon-size = 0;
      alt-tab-small-icon-size = 0;
      alt-tab-window-preview-size = 0;
      animation = 1;
      controls-manager-spacing-size = 0;
      dash-app-running = true;
      panel = true;
      panel-icon-size = 24;
      panel-in-overview = true;
      panel-notification-icon = true;
      panel-size = 36;
      power-icon = true;
      show-apps-button = true;
      support-notifier-showed-version = 34;
      support-notifier-type = 0;
      switcher-popup-delay = true;
      theme = false;
      window-maximized-on-create = false;
      window-picker-icon = true;
      workspace-popup = false;
      workspace-switcher-should-show = false;
    };

    "org/gnome/shell/extensions/trayIconsReloaded" = {
      icon-size = 16;
      tray-position = "right";
    };

    "org/gnome/shell/extensions/user-theme" = {
      name = "shell-Dark-Nord";
    };

    "org/gnome/shell/extensions/vitals" = {
      alphabetize = true;
      fixed-widths = true;
      hide-icons = true;
      hide-zeros = false;
      hot-sensors = [ "_processor_usage_" "_memory_allocated_" ];
      icon-style = 0;
      include-static-info = false;
      menu-centered = false;
      position-in-panel = 0;
      show-battery = false;
      show-fan = false;
      show-memory = true;
      show-system = true;
      show-voltage = false;
      update-time = 1;
      use-higher-precision = true;
    };

    "org/gnome/shell/world-clocks" = {
      locations = [];
    };

  };
}
