{ stdenvNoCC, fetchzip, makeWrapper, lib }:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codexbar";
  version = "0.72.0";

  # Static musl build, so it runs on NixOS without patchelf.
  src = fetchzip {
    url = "https://github.com/steipete/CodexBar/releases/download/v${finalAttrs.version}/CodexBarCLI-v${finalAttrs.version}-linux-musl-x86_64.tar.gz";
    hash = "sha256-Mv+pdu2e0bXYqlJE7ZlPgfFY1fkgmWgCDMD7lq9RGtU=";
    stripRoot = false;
  };

  nativeBuildInputs = [ makeWrapper ];

  # The provider bundle is loaded from next to the real executable, so keep
  # them together in libexec and expose a wrapper like the Homebrew formula.
  installPhase = ''
    mkdir -p $out/libexec $out/bin
    cp -r CodexBarCLI VERSION CodexBar_CodexBarCore.bundle $out/libexec/
    makeWrapper $out/libexec/CodexBarCLI $out/bin/codexbar
  '';

  dontStrip = true;

  meta = {
    description = "Usage and status CLI for AI coding providers";
    homepage = "https://github.com/steipete/CodexBar";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "codexbar";
  };
})
