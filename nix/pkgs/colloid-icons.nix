# Colloid's Nord icons, with the transforms in its symbolic icons baked into
# their shapes (see flatten-svg-transforms.py): GTK 4 draws nothing for a
# symbolic icon's shape drawn through one (e.g. pan-down-symbolic, every
# dropdown's arrow).
{ colloid-icon-theme, python3 }:
(colloid-icon-theme.override { schemeVariants = [ "nord" ]; }).overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ (python3.withPackages (p: [ p.svgelements ])) ];

  # After jdupes linked duplicates together, so grep -r, which skips links,
  # finds each file once.
  postInstall = (old.postInstall or "") + ''
    grep -rlZE --include='*-symbolic.svg' ' transform=' $out/share/icons \
      | xargs -0 python3 ${./flatten-svg-transforms.py}
  '';
})
