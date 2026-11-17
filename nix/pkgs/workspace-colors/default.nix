# The workspace-colors GNOME Shell extension.
# themes: see themes.nix. workspaces: theme names, one per workspace;
# workspaces past the end wrap around.
{ lib, stdenvNoCC, runCommand, imagemagick, writeText, themes, workspaces }:
let
  uuid = "workspace-colors@hans";

  # Screen shapes an anchored wallpaper is cropped for; each monitor shows the
  # closest crop, which GNOME can only zoom about its center.
  shapes = [ [ 16 9 ] [ 16 10 ] [ 21 9 ] [ 32 9 ] [ 3 2 ] [ 4 3 ] [ 5 4 ] ];
  shapeName = shape: "${toString (lib.elemAt shape 0)}x${toString (lib.elemAt shape 1)}";

  # [{ aspect; file; }]: the image cropped to each shape about its anchor.
  crops = { image, anchor ? null, ... }:
    if anchor == null then [ { aspect = 1; file = image; } ]
    else
      let
        cropped = runCommand "wallpaper-crops" { nativeBuildInputs = [ imagemagick ]; } ''
          mkdir $out
          read width height < <(magick identify -format '%w %h\n' ${image})
          for shape in ${lib.concatMapStringsSep " " shapeName shapes}; do
            geometry=$(awk -v W=$width -v H=$height -v w=''${shape%x*} -v h=''${shape#*x} \
              -v ax=${toString anchor.x} -v ay=${toString anchor.y} 'BEGIN {
                if (W * h > H * w) { cw = int(H * w / h); ch = H } else { cw = W; ch = int(W * h / w) }
                printf "%dx%d+%d+%d", cw, ch, int((W - cw) * ax), int((H - ch) * ay)
              }')
            magick ${image} -crop "$geometry" +repage -quality 92 $out/$shape.jpg
          done
        '';
      in
      map (shape: {
        aspect = lib.elemAt shape 0 * 1.0 / lib.elemAt shape 1;
        file = "${cropped}/${shapeName shape}.jpg";
      }) shapes;

  schemes = map (name:
    let desktop = themes.${name}.desktop; in
    builtins.removeAttrs desktop [ "anchor" ]
    // { theme = name; }
    // lib.optionalAttrs (desktop ? image) { image = crops desktop; }
  ) workspaces;
  shellThemes = lib.mapAttrs (name: { tint, ui, ... }: {
    inherit tint;
    accent = ui.accent;
    accentForeground = ui.accentForeground;
  }) themes;
in
stdenvNoCC.mkDerivation {
  pname = "gnome-shell-extension-workspace-colors";
  version = "1";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./metadata.json (lib.fileset.fileFilter (f: f.hasExt "js") ./.) ];
  };
  installPhase = ''
    dir=$out/share/gnome-shell/extensions/${uuid}
    install -Dm644 -t $dir metadata.json *.js
    install -Dm644 ${writeText "schemes.json" (builtins.toJSON schemes)} $dir/schemes.json
    install -Dm644 ${writeText "themes.json" (builtins.toJSON shellThemes)} $dir/themes.json
  '';
  passthru.extensionUuid = uuid;
}
