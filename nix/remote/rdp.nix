{ config, pkgs, ... }:

# GNOME Remote Login: a system RDP server that lands on the GDM greeter in its
# own virtual display, so it works from boot and without a monitor attached.
# The TLS pair and the RDP-layer password come from Syncthing'd ~/Sync/keys;
# GDM still asks for the account password after connecting.
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
}
