# A Blur.BlurEffect with rounded corners, which Blur my Shell uses for dynamic
# blur when GNOME Shell finds it (through the session's GI_TYPELIB_PATH, see
# services.desktopManager.gnome.sessionPath). It links against mutter's
# internal libraries, which live outside the library path.
{ lib, stdenv, fetchFromGitHub, meson, ninja, pkg-config, gobject-introspection, glib, mutter }:
stdenv.mkDerivation (finalAttrs: {
  pname = "gnome-rounded-blur";
  version = "1.0.2";

  src = fetchFromGitHub {
    owner = "kancko";
    repo = "gnome-rounded-blur";
    tag = "v${finalAttrs.version}";
    hash = "sha256-2zRQnORmVQMuubLOZ+0mHDQhDoc7V/+2JM3gmYPia2s=";
  };

  strictDeps = true;
  nativeBuildInputs = [ meson ninja pkg-config gobject-introspection ];
  # mutter's pkg-config files require its whole build dependency set, which it
  # doesn't propagate.
  buildInputs = [ glib mutter ] ++ mutter.buildInputs ++ (mutter.propagatedBuildInputs or [ ]);

  postFixup = ''
    patchelf --add-rpath ${mutter.libdir} $out/lib/libblur-effect-1.0.so.1.0.0
  '';

  meta = {
    description = "Blur.BlurEffect with corner radius support for GNOME Shell extensions";
    homepage = "https://github.com/kancko/gnome-rounded-blur";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
})
