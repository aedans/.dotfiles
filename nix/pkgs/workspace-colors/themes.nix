# Workspace themes. Each gives:
#   desktop   the workspace's wallpaper (image) and the colors the shell blends
#             along the workspace switch: background (shown until the image
#             loads), top bar and the overview's background around the
#             workspaces (panel, chosen near the tint's overview grey), dock,
#             and the cursor's accent (cursor, fully saturated in the theme's
#             accent hue so the pointer is easy to find, at a relative
#             luminance of about 0.33 so no workspace's is harder to see).
#             anchor (x and y, 0 to 1 from the top left) is the part of the
#             image that stays in view when a screen's shape cuts it; it's
#             centered without one.
#   tint      hue (degrees) and HLS saturation the shell theme's greys take
#   ui        window colors: window, view (content and lists), raised (headerbar,
#             popovers), sidebar, border, button, hover, text, accent (accent
#             backgrounds), accentText (accent-colored text), accentForeground
#             (text on accent backgrounds)
#   terminal  foreground, background and 16-color palette
#   icons     the filter recoloring Nautilus's file icons (Colloid-Nord), as
#             sepia, saturate and hue-rotate amounts; sepia moves them to an
#             orange from which hue-rotate turns them, without the sweep through
#             pink a large hue-rotate interpolates through
{
  catppuccin = {
    desktop = {
      image = ../../../.config/backgrounds/catppuccin.jpg;
      background = "#5b4a9e"; panel = "#19192f"; dock = "#1e1e2e"; cursor = "#d073ff";
    };
    tint = { hue = 240; saturation = 0.3; };
    ui = {
      window = "#1e1e2e"; view = "#181825"; raised = "#313244"; sidebar = "#181825";
      border = "#11111b"; button = "#45475a"; hover = "#585b70"; text = "#cdd6f4";
      accent = "#cba6f7"; accentText = "#cba6f7"; accentForeground = "#1e1e2e";
    };
    terminal = {
      foreground = "#cdd6f4";
      background = "#1e1e2e";
      palette = [
        "#45475a" "#f38ba8" "#a6e3a1" "#f9e2af" "#89b4fa" "#f5c2e7" "#94e2d5" "#bac2de"
        "#585b70" "#f38ba8" "#a6e3a1" "#f9e2af" "#89b4fa" "#f5c2e7" "#94e2d5" "#a6adc8"
      ];
    };
    icons = { sepia = 0; saturate = 1.3; hueRotate = 50; };
  };

  nord = {
    desktop = {
      image = ../../../.config/backgrounds/nord.jpg;
      background = "#3a4ba0"; panel = "#1d222b"; dock = "#2e3440"; cursor = "#00a8d7";
    };
    tint = { hue = 220; saturation = 0.2; };
    ui = {
      window = "#2e3440"; view = "#292e39"; raised = "#3b4252"; sidebar = "#343a47";
      border = "#242933"; button = "#4c566a"; hover = "#566178"; text = "#eceff4";
      accent = "#5e81ac"; accentText = "#88c0d0"; accentForeground = "#eceff4";
    };
    terminal = {
      foreground = "#d8dee9";
      background = "#2e3440";
      palette = [
        "#3b4252" "#bf616a" "#a3be8c" "#ebcb8b" "#81a1c1" "#b48ead" "#88c0d0" "#e5e9f0"
        "#4c566a" "#bf616a" "#a3be8c" "#ebcb8b" "#81a1c1" "#b48ead" "#8fbcbb" "#eceff4"
      ];
    };
    icons = { sepia = 0; saturate = 1; hueRotate = 0; };
  };

  gruvbox = {
    desktop = {
      image = ../../../.config/backgrounds/gruvbox.jpg;
      background = "#7a3f1d"; panel = "#2c241c"; dock = "#282828"; cursor = "#ff710b";
    };
    tint = { hue = 30; saturation = 0.22; };
    ui = {
      window = "#282828"; view = "#1d2021"; raised = "#3c3836"; sidebar = "#32302f";
      border = "#141617"; button = "#504945"; hover = "#665c54"; text = "#ebdbb2";
      accent = "#d65d0e"; accentText = "#fe8019"; accentForeground = "#fbf1c7";
    };
    terminal = {
      foreground = "#ebdbb2";
      background = "#282828";
      palette = [
        "#282828" "#cc241d" "#98971a" "#d79921" "#458588" "#b16286" "#689d6a" "#a89984"
        "#928374" "#fb4934" "#b8bb26" "#fabd2f" "#83a598" "#d3869b" "#8ec07c" "#ebdbb2"
      ];
    };
    icons = { sepia = 1; saturate = 2.2; hueRotate = -12; };
  };

  everforest = {
    desktop = {
      # The dragon, top left.
      image = ../../../.config/backgrounds/everforest.jpg; anchor = { x = 0; y = 0; };
      background = "#3f6a4a"; panel = "#1e2a26"; dock = "#2d353b"; cursor = "#5daf00";
    };
    tint = { hue = 160; saturation = 0.18; };
    ui = {
      window = "#2d353b"; view = "#232a2e"; raised = "#343f44"; sidebar = "#272e33";
      border = "#1e2326"; button = "#475258"; hover = "#4f585e"; text = "#d3c6aa";
      accent = "#a7c080"; accentText = "#a7c080"; accentForeground = "#2d353b";
    };
    terminal = {
      foreground = "#d3c6aa";
      background = "#2d353b";
      palette = [
        "#343f44" "#e67e80" "#a7c080" "#dbbc7f" "#7fbbb3" "#d699b6" "#83c092" "#d3c6aa"
        "#868d80" "#e67e80" "#a7c080" "#dbbc7f" "#7fbbb3" "#d699b6" "#83c092" "#d3c6aa"
      ];
    };
    icons = { sepia = 1; saturate = 1.2; hueRotate = 50; };
  };
}
