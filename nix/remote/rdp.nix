{ config, pkgs, ... }:

# GNOME Remote Login: a system RDP server that lands on the GDM greeter in its
# own virtual display, so it works from boot and without a monitor attached.
# The TLS pair and the RDP-layer password come from Syncthing'd ~/Sync/keys;
# GDM still asks for the account password after connecting.
let
  keys = "/home/hans/Sync/keys/${config.networking.hostName}-rdp";
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
    script = ''
      grdctl --system rdp set-tls-cert ${keys}-tls.crt
      grdctl --system rdp set-tls-key ${keys}-tls.key
      grdctl --system rdp set-credentials hans "$(cat ${keys}-password)"
      grdctl --system rdp enable
    '';
  };
}
