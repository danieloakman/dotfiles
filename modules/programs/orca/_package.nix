# Orca ADE — pinned Linux AppImage from stablyai/orca releases.
# https://orca.dev/ · https://github.com/stablyai/orca/releases
#
# Bump version + both hashes together (and the skills source hash in default.nix):
#   nix store prefetch-file "https://github.com/stablyai/orca/releases/download/vVERSION/orca-linux.AppImage"
#   nix store prefetch-file "https://github.com/stablyai/orca/releases/download/vVERSION/orca-linux-arm64.AppImage"
{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  version ? "1.4.258",
}:
let
  pname = "orca-ide";

  src =
    fetchurl
      {
        x86_64-linux = {
          url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
          hash = "sha256-bXi+zAbqjqas4tDq5U8ZnSYWDVhMHnR/POOHXAv9eOc=";
        };
        aarch64-linux = {
          url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux-arm64.AppImage";
          hash = "sha256-wb4w6gcH5Fw1Xiu9mAlzmPB9D9ioMqbevFTcOBb1f4k=";
        };
      }
      .${stdenv.hostPlatform.system}
      or (throw "orca-ide: unsupported system ${stdenv.hostPlatform.system}");

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit
    pname
    version
    src
    ;

  extraInstallCommands = ''
    # Desktop entry / icons from the AppImage (names vary slightly by release).
    desktop=""
    for candidate in orca-ide.desktop orca.desktop; do
      if [ -f ${appimageContents}/$candidate ]; then
        desktop=$candidate
        break
      fi
    done
    if [ -n "$desktop" ]; then
      install -Dm444 ${appimageContents}/$desktop $out/share/applications/orca-ide.desktop
      substituteInPlace $out/share/applications/orca-ide.desktop \
        --replace-quiet 'Exec=AppRun --no-sandbox' 'Exec=orca-ide' \
        --replace-quiet 'Exec=AppRun' 'Exec=orca-ide'
    fi

    if [ -d ${appimageContents}/usr/share/icons ]; then
      mkdir -p $out/share/icons
      cp -a ${appimageContents}/usr/share/icons/. $out/share/icons/
    fi
  '';

  meta = {
    description = "Agent development environment for running coding agents in parallel worktrees";
    homepage = "https://orca.dev/";
    downloadPage = "https://github.com/stablyai/orca/releases";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "orca-ide";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
