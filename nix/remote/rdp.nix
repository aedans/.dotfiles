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
  systemd.services.gnome-remote-desktop.wantedBy = [ "graphical.target" ];

  systemd.services.gnome-remote-desktop-configure = {
    description = "Configure GNOME Remote Login";
    wantedBy = [ "gnome-remote-desktop.service" ];
    after = [ "gnome-remote-desktop.service" ];
    path = [ pkgs.gnome-remote-desktop ];
    serviceConfig.Type = "oneshot";
    script = ''
      grdctl --system rdp set-tls-cert ${keys}-tls.crt
      grdctl --system rdp set-tls-key ${keys}-tls.key
      grdctl --system rdp set-credentials hans "$(cat ${keys}-password)"
      grdctl --system rdp enable
    '';
  };
}
