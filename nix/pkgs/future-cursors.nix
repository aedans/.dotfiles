# The Future-cursors theme (the Future-cursors submodule), built from its cyan
# variant the way its build.sh does: the cyan is the accent the workspace-colors
# extension recolors per workspace, so it has to be a color no other part of a
# cursor uses.
{ lib, stdenvNoCC, librsvg, xcursorgen }:
let
  src = ../../Future-cursors/src;
in
stdenvNoCC.mkDerivation {
  pname = "future-cursors";
  version = "1";
  inherit src;
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
