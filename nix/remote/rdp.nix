{ config, pkgs, ... }:

# Two RDP servers, both reached as user hans with the password in ~/Sync/keys:
# - port 3389 shares the logged-in GNOME session on a virtual monitor, so it
#   works with the display off and keeps running apps;
# - port 3390 is GNOME Remote Login, a system server that lands on the GDM
#   greeter in its own virtual display, for when nobody is logged in.
# The TLS pair and password come from Syncthing'd ~/Sync/keys.
let
  keys = "/home/hans/Sync/keys/${config.networking.hostName}-rdp";
  state = config.users.users.gnome-remote-desktop.home;
in
{
  services.gnome.gnome-remote-desktop.enable = true;

  # The upstream unit's [Install] section isn't applied by systemd.packages.
  # The daemon only reads its settings at startup, so it requires the setup
  # unit: rerunning setup on a switch restarts the daemon with them.
  systemd.services.gnome-remote-desktop = {
    wantedBy = [ "graphical.target" ];
    requires = [ "gnome-remote-desktop-configure.service" ];
    after = [ "gnome-remote-desktop-configure.service" ];
    # It can hang on SIGTERM after a dropped connection; don't stall switches.
    serviceConfig.TimeoutStopSec = 10;
  };

  # grdctl --system only writes the daemon's settings file, so this runs first.
  # RemainAfterExit lets a switch rerun it when the script changes.
  systemd.services.gnome-remote-desktop-configure = {
    description = "Configure GNOME Remote Login";
    wantedBy = [ "multi-user.target" ];
    # grdctl --system re-execs itself through pkexec, even as root.
    path = [ pkgs.gnome-remote-desktop "/run/wrappers" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # grdctl --system reads the TLS pair as the gnome-remote-desktop user,
    # which can't enter /home/hans, so stage a copy it owns first.
    script = ''
      install -D -o gnome-remote-desktop -g gnome-remote-desktop -m 644 ${keys}-tls.crt ${state}/rdp-tls.crt
      install -D -o gnome-remote-desktop -g gnome-remote-desktop -m 600 ${keys}-tls.key ${state}/rdp-tls.key
      grdctl --system rdp set-tls-cert ${state}/rdp-tls.crt
      grdctl --system rdp set-tls-key ${state}/rdp-tls.key
      grdctl --system rdp set-credentials hans "$(cat ${keys}-password)"
      # Leave the default port to sharing the logged-in session, which
      # clients like GNOME Connections reach without a port.
      grdctl --system rdp set-port 3390
      grdctl --system rdp enable
    '';
  };

  # Session sharing mirrors the system pair: setup first, then the daemon,
  # which requires it. Both only run for hans, not in GDM's greeter session.
  systemd.user.services.gnome-remote-desktop = {
    wantedBy = [ "gnome-session.target" ];
    requires = [ "gnome-remote-desktop-configure.service" ];
    after = [ "gnome-remote-desktop-configure.service" ];
    unitConfig.ConditionUser = "hans";
  };

  # The credentials go to the login keyring, which PAM has unlocked by the
  # time gnome-session.target starts.
  systemd.user.services.gnome-remote-desktop-configure = {
    description = "Configure GNOME Remote Desktop session sharing";
    wantedBy = [ "gnome-session.target" ];
    unitConfig.ConditionUser = "hans";
    path = [ pkgs.gnome-remote-desktop pkgs.dconf ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      grdctl rdp set-tls-cert ${keys}-tls.crt
      grdctl rdp set-tls-key ${keys}-tls.key
      grdctl rdp set-credentials hans "$(cat ${keys}-password)"
      grdctl rdp set-port 3389
      grdctl rdp disable-view-only
      # Share a virtual monitor instead of mirroring one, so it works with
      # no display attached. grdctl has no command for this setting.
      dconf write /org/gnome/desktop/remote-desktop/rdp/screen-share-mode "'extend'"
      grdctl rdp enable
    '';
  };
}
