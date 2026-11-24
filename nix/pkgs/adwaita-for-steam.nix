# Adwaita-for-Steam as a Millennium theme: Millennium reads the repository's
# skin.json directly, so the theme is the unmodified source tree.
{ stdenvNoCC, fetchFromGitHub }:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "adwaita-for-steam";
  version = "4.5";
  src = fetchFromGitHub {
    owner = "tkashkin";
    repo = "Adwaita-for-Steam";
    rev = finalAttrs.version;
    hash = "sha256-BflUVdtuAEDhtoEkF9w0JntaKVUNud3prxMGDST+Tkk=";
  };

  installPhase = ''
    cp -r . $out
  '';
})
