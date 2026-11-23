# LibreOffice in Nord: Libre Nord Dark's color scheme, installed as a user
# extension (see nix/pkgs/libre-nord). Its menus, toolbars and documents
# are drawn by LibreOffice from that scheme, so they don't follow the workspace
# colors; its GTK windows (title bars, menu bar, dialogs) do, except for the
# buttons and other controls LibreOffice's own GTK stylesheet colors from it.
{ pkgs, ... }:
let
  libreNord = "${pkgs.callPackage ./pkgs/libre-nord { }}/libre-nord-dark.oxt";
in
{
  users.users.hans.packages = [ pkgs.libreoffice ];

  # Extensions live in the profile, so unopkg installs it there, again only
  # when the file changes. It fails while LibreOffice runs; the next switch
  # retries.
  home-manager.users.hans = { config, lib, ... }: {
    home.activation.libreNord = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      stamp="${config.xdg.configHome}/libreoffice/4/user/libre-nord"
      if [ "$(cat "$stamp" 2>/dev/null)" != "${libreNord}" ]; then
        if run ${pkgs.libreoffice}/bin/unopkg add --force --suppress-license ${libreNord}; then
          [[ -v DRY_RUN ]] || echo "${libreNord}" > "$stamp"
        else
          warnEcho "Libre Nord wasn't installed; close LibreOffice and switch again"
        fi
      fi
    '';
  };
}
