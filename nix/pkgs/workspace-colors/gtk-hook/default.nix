# Per-window GTK themes chosen by the workspace-colors extension.
# css / gtk3Css: stylesheets defining ws-<theme> window classes and
# ws-animating transitions, for GTK 4 and GTK 3 applications.
# terminalPalettes: { <theme> = { foreground; background; palette = [ 16 colors ]; }; }
# for VTE terminals. Put lib/workspace-theme/preload.so in the session's LD_PRELOAD.
{ lib, stdenv, pkg-config, gtk3, gtk4, writeText, css, gtk3Css ? writeText "empty.css" "", terminalPalettes ? { } }:
let
  palettes = writeText "terminal-palettes.ini" (lib.generators.toINI { } (lib.mapAttrs
    (theme: p: p // { palette = lib.concatStringsSep ";" p.palette; })
    terminalPalettes));
  dir = "$out/lib/workspace-theme";
in
stdenv.mkDerivation {
  pname = "workspace-theme-gtk-hook";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ gtk3 gtk4 ];
  # The hooks are linked against nothing: each binds to the GTK already loaded
  # in the application, which need not be this exact build.
  buildPhase = ''
    hook() {
      $CC -shared -fPIC -O2 -Wall -Wno-deprecated-declarations -o $1 \
        ${./hook.c} ${./windows.c} ${./terminal.c} -I${./.} $(pkg-config --cflags $2) \
        -DTERMINAL_PALETTES='"${palettes}"' "''${@:3}"
    }
    hook hook-gtk4.so gtk4 -DTHEME_CSS='"${css}"'
    hook hook-gtk3.so gtk+-3.0 -DTHEME_CSS='"${gtk3Css}"' -DHOOK_GTK3
    $CC -shared -fPIC -O2 -Wall -o preload.so ${./preload.c} -ldl \
      $(pkg-config --cflags glib-2.0) \
      -DHOOK_GTK4_PATH="\"${dir}/hook-gtk4.so\"" -DHOOK_GTK3_PATH="\"${dir}/hook-gtk3.so\""
  '';
  installPhase = ''
    install -Dm644 -t ${dir} hook-gtk4.so hook-gtk3.so preload.so
  '';
}
