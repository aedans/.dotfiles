{ lib, ... }:
let
  # Written by dump-firefox.sh: one add-on ID per line.
  extensions = lib.filter (id: id != "")
    (lib.splitString "\n" (builtins.readFile ../.config/firefox/extensions.txt));
in
{
  programs.firefox = {
    enable = true;
    # normal_installed installs each add-on from AMO and keeps it updated, but
    # leaves it in the profile like a hand-installed one. Removing one means
    # deleting its line here and rebuilding before uninstalling it in Firefox,
    # since policy-installed add-ons can only be disabled.
    policies.ExtensionSettings = lib.genAttrs extensions (id: {
      installation_mode = "normal_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${lib.escapeURL id}/latest.xpi";
    });
    # Tabs in the title bar, so Firefox draws it in its theme instead of GNOME
    # drawing it in the desktop's. Set as the user's value on every start.
    policies.Preferences."browser.tabs.inTitlebar" = {
      Value = 1;
      Status = "user";
    };
  };
}
