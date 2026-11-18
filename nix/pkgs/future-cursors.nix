# The Future-cursors theme, built from its cyan variant the way its build.sh
# does: the cyan is the accent the workspace-colors extension recolors per
# workspace, so it has to be a color no other part of a cursor uses.
{ stdenvNoCC, fetchFromGitHub, librsvg, xcursorgen }:
stdenvNoCC.mkDerivation {
  pname = "future-cursors";
  version = "0-unstable-2024-10-07";
  src = fetchFromGitHub {
    owner = "aedans";
    repo = "Future-cursors";
    rev = "5e225eeeb9842188c5affc6d30ce979ac16b3cb4";
    hash = "sha256-5imWnG/rIUH/8lzaFbxkn0rGcmWr4GuqipwSa7YAZM4=";
  };
  sourceRoot = "source/src";
  nativeBuildInputs = [ librsvg xcursorgen ];

  buildPhase = ''
    for dir in x1:32 x1_25:40 x1_5:48 x2:64; do
      mkdir -p ''${dir%:*}
      for svg in svg-cyan/*.svg; do
        name=''${svg##*/}
        rsvg-convert -w ''${dir#*:} -h ''${dir#*:} -o ''${dir%:*}/''${name%.svg}.png $svg
      done
    done

    mkdir cursors
    for config in config/*.cursor; do
      name=''${config##*/}
      xcursorgen $config cursors/''${name%.cursor}
    done
    # cursorList: an alias and the cursor it names, per line.
    while read alias target; do
      [ -e cursors/$alias ] || ln -s $target cursors/$alias
    done < cursorList
  '';

  installPhase = ''
    dir=$out/share/icons/Future-cursors
    mkdir -p $dir
    cp -r cursors $dir
    printf '[Icon Theme]\nName=Future Cursors\n' > $dir/index.theme
  '';

  passthru = {
    themeName = "Future-cursors";
    # The accent's color in svg-cyan.
    accent = "#23afc8";
  };
}
