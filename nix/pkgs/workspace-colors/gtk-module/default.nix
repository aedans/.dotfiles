# The workspace-theme GTK module: per-window GTK themes chosen by the
# workspace-colors extension. GTK loads it into every application through
# GTK_MODULES: put this package's lib/gtk-* in GTK_PATH (NixOS does for the
# system profile) and "workspace-theme" in GTK_MODULES. GTK 4 needs
# patches/gtk4-modules.patch for that.
# css / gtk3Css: stylesheets defining ws-<theme> window classes and
# ws-animating transitions, for GTK 4 and GTK 3 applications.
# terminalPalettes: { <theme> = { foreground; background; palette = [ 16 colors ]; }; }
# for VTE terminals.
{ lib, stdenv, pkg-config, gtk3, gtk4, writeText, css, gtk3Css ? writeText "empty.css" "", terminalPalettes ? { } }:
let
  palettes = writeText "terminal-palettes.ini" (lib.generators.toINI { } (lib.mapAttrs
    (theme: p: p // { palette = lib.concatStringsSep ";" p.palette; })
    terminalPalettes));
in
stdenv.mkDerivation {
  pname = "workspace-theme-gtk-module";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ gtk3 gtk4 ];
  # Linked against nothing: each binds to the GTK already loaded in the
  # application, which need not be this exact build. Each sits in the
  # versioned directory only its own GTK searches.
  buildPhase = ''
    module() {
      $CC -shared -fPIC -O2 -Wall -Wno-deprecated-declarations -o $1 \
        ${./module.c} ${./windows.c} ${./terminal.c} -I${./.} $(pkg-config --cflags $2) \
        -DTERMINAL_PALETTES='"${palettes}"' "''${@:3}"
    }
    module gtk4.so gtk4 -DTHEME_CSS='"${css}"'
    module gtk3.so gtk+-3.0 -DTHEME_CSS='"${gtk3Css}"' -DMODULE_GTK3
  '';
  installPhase = ''
    install -Dm644 gtk4.so $out/lib/gtk-4.0/4.0.0/modules/libworkspace-theme.so
    install -Dm644 gtk3.so $out/lib/gtk-3.0/3.0.0/modules/libworkspace-theme.so
  '';
  passthru.moduleName = "workspace-theme";
}
