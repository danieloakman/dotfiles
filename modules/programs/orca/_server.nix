# Orca headless server — pinned linux tarball from stablyai/orca releases.
# https://orca.dev/docs/remote-servers · https://github.com/stablyai/orca/releases
#
# Prefer this over the desktop Electron package for `orca serve`: plain Node
# orcad, smaller, no GUI deps.
#
# Bump version + both hashes together (and AppImage / skills hashes in sibling files):
#   nix store prefetch-file "https://github.com/stablyai/orca/releases/download/vVERSION/orca-server-linux-x64.tar.gz"
#   nix store prefetch-file "https://github.com/stablyai/orca/releases/download/vVERSION/orca-server-linux-arm64.tar.gz"
{
  lib,
  stdenv,
  fetchurl,
  version ? "1.4.258",
}:
let
  pname = "orca-server";

  src =
    fetchurl
      {
        x86_64-linux = {
          url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-server-linux-x64.tar.gz";
          hash = "sha256-/X8j9ftv5D+ymC0XQ413L6x8xlyCCKIS0P+yJLUE4xE=";
        };
        aarch64-linux = {
          url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-server-linux-arm64.tar.gz";
          hash = "sha256-oSeZI3ABlujM2UlS/qA59tmPXU+Uha/KApXt3qjMsDM=";
        };
      }
      .${stdenv.hostPlatform.system}
      or (throw "orca-server: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  inherit pname version src;

  sourceRoot = "orca-server-${version}-linux-${
    if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"
  }";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/${pname} $out/bin
    cp -a . $out/lib/${pname}/
    # Launcher resolves its install root via readlink -f; keep the real script
    # under lib/ and expose a stable bin name for the systemd unit / PATH.
    ln -s ../lib/${pname}/bin/orca-ide $out/bin/orca-serve
    runHook postInstall
  '';

  meta = {
    description = "Headless Orca runtime (orcad) for `orca serve`";
    homepage = "https://orca.dev/";
    downloadPage = "https://github.com/stablyai/orca/releases";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "orca-serve";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
