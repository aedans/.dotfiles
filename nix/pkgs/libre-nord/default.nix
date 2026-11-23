# Libre Nord Dark, a LibreOffice extension with a Nord color scheme, made the
# current scheme, with this directory's configuration added to it: theming on
# (Appearance.xcu), without which the scheme's UI colors don't apply, and the
# colors the scheme leaves out (Colors.xcu).
{ stdenvNoCC, fetchurl, zip, unzip, lib }:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "libre-nord-dark";
  version = "1.0.5";

  src = fetchurl {
    url = "https://github.com/gomesluiz/libre-nord/releases/download/v${finalAttrs.version}/libre-nord-dark.oxt";
    hash = "sha256-+NbDiPBYCzO4x0r8SyLsb4ChIipNqBsptzdc4/+alk4=";
  };

  nativeBuildInputs = [ zip unzip ];

  unpackPhase = ''
    mkdir oxt
    unzip -q $src -d oxt
  '';

  buildPhase = ''
    cd oxt
    for file in Appearance.xcu Colors.xcu; do
      cp ${./.}/$file .
      substituteInPlace META-INF/manifest.xml --replace-fail '</manifest:manifest>' \
        "<manifest:file-entry manifest:full-path=\"$file\" manifest:media-type=\"application/vnd.sun.star.configuration-data\"/></manifest:manifest>"
    done
  '';

  installPhase = ''
    mkdir $out
    zip -qrX $out/libre-nord-dark.oxt .
  '';

  meta = {
    description = "Nord color scheme for LibreOffice";
    homepage = "https://github.com/gomesluiz/libre-nord";
    license = lib.licenses.mit;
  };
})
