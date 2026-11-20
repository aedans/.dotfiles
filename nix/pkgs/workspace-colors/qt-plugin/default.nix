# The workspace-theme Qt plugin: per-window Qt palettes chosen by the
# workspace-colors extension, built for the Qt whose callPackage calls it (Qt 5
# or 6). Qt loads it into every application as a generic plugin: put this
# package's plugin directory in Qt's plugin path (NixOS's Qt derives one from
# each PATH entry, so the system profile's is found) and "workspacetheme" in
# QT_QPA_GENERIC_PLUGINS.
# themes: see ../themes.nix; each theme's ui colors become its palette.
{ lib, stdenv, pkg-config, qtbase, writeText, themes }:
let
  major = lib.versions.major qtbase.version;
  moc = if major == "5" then "${lib.getDev qtbase}/bin/moc" else "${qtbase}/libexec/moc";
  palettes = writeText "workspace-theme-palettes.json"
    (builtins.toJSON (lib.mapAttrs (name: theme: theme.ui) themes));
in
stdenv.mkDerivation {
  pname = "workspace-theme-qt${major}-plugin";
  version = "1";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (f: !f.hasExt "nix") ./.;
  };
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ qtbase ];
  dontWrapQtApps = true;
  # Linked against this Qt, but an application loads it into its own: the
  # loader reuses the Qt libraries already loaded under the same names.
  buildPhase = ''
    modules="Qt${major}Widgets Qt${major}DBus"
    # moc expands the plugin's interface name from Qt's headers.
    ${moc} $(pkg-config --cflags-only-I $modules) plugin.cpp -o plugin.moc
    $CXX -shared -fPIC -O2 -Wall -std=c++17 -I. -o libworkspacetheme.so \
      plugin.cpp windows.cpp palettes.cpp -DTHEMES_JSON='"${palettes}"' \
      $(pkg-config --cflags --libs $modules)
  '';
  installPhase = ''
    install -Dm644 libworkspacetheme.so $out/${qtbase.qtPluginPrefix}/generic/libworkspacetheme.so
  '';
  passthru.pluginName = "workspacetheme";
}
