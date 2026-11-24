# Millennium's theme and settings. Millennium deep-merges its defaults into
# config.json and saves it by renaming a temp file over it, which replaces the
# store link with a real file; force lets each activation put ours back.
{ pkgs, ... }:
let
  adwaita = pkgs.callPackage ../nix/pkgs/adwaita-for-steam.nix { };
  theme = "adwaita";
in
{
  xdg.dataFile."Steam/millennium/themes/${theme}".source = adwaita;

  xdg.configFile."millennium/config.json" = {
    force = true;
    text = builtins.toJSON {
      general = {
        checkForMillenniumUpdates = false;
        checkForPluginAndThemeUpdates = false;
        shouldShowThemePluginUpdateNotifications = false;
      };
      misc.hasShownWelcomeModal = true;
      notifications.showUpdateNotifications = false;
      themes = {
        activeTheme = theme;
        conditions.${theme} = {
          "Color theme" = "Gruvbox";
          "Color scheme" = "System";
          "Accent color" = "Theme default";
        };
      };
    };
  };
}
