# The system as a throwaway QEMU VM, for trying changes before switching; it
# shares the host's /nix/store. Only the settings here differ from the host.
#   nix build --impure .#nixosConfigurations.<host>.config.system.build.vm
#   mkdir -p vm-journal && ./result/bin/run-<host>-vm      (rm <host>.qcow2 to reset)
# Switch workspaces with Ctrl+1..4 (the host captures its own shortcuts); move
# the focused window with Ctrl+Shift+1..4, or move it and follow with
# Ctrl+Shift+Page Up/Down. The guest takes the QEMU window's size, so maximize
# it. The guest journal is mirrored to vm-journal/journal.txt next to the disk.
{ pkgs, lib, ... }:
let
  # What bootstrap.sh dconf-loads on the host, as one keyfile directory with
  # sections made absolute (dumps are relative to their root).
  dconfDumps = pkgs.runCommand "dconf-dumps" { } ''
    mkdir $out
    convert() {
      sed -E -e "s#^\[/\]\$#[$1]#;t" -e "s#^\[(.+)\]\$#[$1/\1]#" "$2"
    }
    convert org/gnome/shell ${../.config/dconf/-org-gnome-shell-.txt} > $out/shell
    convert org/gnome/desktop ${../.config/dconf/-org-gnome-desktop-.txt} > $out/desktop
    convert org/gnome/mutter ${../.config/dconf/-org-gnome-mutter-.txt} > $out/mutter
  '';
  switchKey = n: [ "<Control>${toString n}" ];
  moveKey = n: [ "<Control><Shift>${toString n}" ];
in
{
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      # GPU-accelerated so animations run at full speed. Without the menu bar, a
      # fullscreen guest gets the host screen's exact size (Ctrl+Alt+F leaves
      # fullscreen, Ctrl+Alt+G releases the mouse).
      qemu.options = [ "-vga none" "-device virtio-vga-gl" "-display gtk,gl=on,show-menubar=off" ];
      sharedDirectories.journal = { source = "\${NIX_DISK_IMAGE%/*}/vm-journal"; target = "/mnt/journal"; };
    };

    systemd.services.journal-to-host = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.bash}/bin/bash -c 'journalctl -b -f -o short-monotonic > /mnt/journal/journal.txt'";
    };
    environment.sessionVariables.G_MESSAGES_DEBUG = "workspace-theme";
    environment.sessionVariables.QT_LOGGING_RULES = "workspace-theme.debug=true";
    # QEMU's window shows the guest's hardware cursor with red and blue
    # swapped, so the guest draws its cursor itself.
    environment.sessionVariables.MUTTER_DEBUG_DISABLE_HW_CURSORS = "1";

    # The guest's GPU is virtio, not the host's NVIDIA card.
    services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
    hardware.nvidia-container-toolkit.enable = lib.mkForce false;
    # RDP reads its keys from ~/Sync, which the guest doesn't have.
    systemd.services.gnome-remote-desktop-configure.enable = false;
    systemd.services.gnome-remote-desktop.enable = false;
    systemd.user.services.gnome-remote-desktop-configure.enable = false;
    systemd.user.services.gnome-remote-desktop.enable = false;

    services.displayManager.autoLogin = { enable = true; user = "hans"; };
    services.gnome.gnome-initial-setup.enable = false;
    users.users.hans.password = "hans";

    # Earlier databases win, so the VM's shortcuts come before the dumps.
    programs.dconf.profiles.user.databases = [
      { settings."org/gnome/desktop/wm/keybindings" = {
        switch-to-workspace-1 = switchKey 1;
        switch-to-workspace-2 = switchKey 2;
        switch-to-workspace-3 = switchKey 3;
        switch-to-workspace-4 = switchKey 4;
        move-to-workspace-1 = moveKey 1;
        move-to-workspace-2 = moveKey 2;
        move-to-workspace-3 = moveKey 3;
        move-to-workspace-4 = moveKey 4;
        move-to-workspace-left = [ "<Control><Shift>Page_Up" ];
        move-to-workspace-right = [ "<Control><Shift>Page_Down" ];
      }; }
      { keyfiles = [ dconfDumps ]; }
    ];
  };
}
