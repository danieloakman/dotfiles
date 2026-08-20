# Standalone herdr-gui release binary (Bun runtime + embedded frontend).
# https://github.com/powerfooI/herdr-gui
{ lib
, stdenvNoCC
, fetchurl
, ...
}:
let
  version = "0.4.2";

  # Prefetch after a version bump:
  #   nix store prefetch-file "https://github.com/powerfooI/herdr-gui/releases/download/vVERSION/ASSET"
  assetMap = {
    x86_64-linux = "herdr-gui-linux-x64.tar.xz";
    aarch64-linux = "herdr-gui-linux-arm64.tar.xz";
    x86_64-darwin = "herdr-gui-darwin-x64.tar.xz";
    aarch64-darwin = "herdr-gui-darwin-arm64.tar.xz";
  };

  hashes = {
    x86_64-linux = "sha256-DaHrkGjwgu93VQXijfE5AIOivFITleX9TNONJDRkMUA=";
    aarch64-linux = "sha256-zU9w0AeQCjP9X94d9+/dG7SePMAdBtQliEBUhR1SRUU=";
    x86_64-darwin = "sha256-5AZyOvoH5GsvRp/4cuVhD1qHN/tWenbn6Trbsp1Cu6g=";
    aarch64-darwin = "sha256-aG0h/kVM1SuE4xeA6y5dKyHblh8k6Lkn7AhWyI8goNY=";
  };

  system = stdenvNoCC.hostPlatform.system;
  asset =
    assetMap.${system}
      or (throw "herdr-gui: unsupported system ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "herdr-gui";
  inherit version;

  src = fetchurl {
    url = "https://github.com/powerfooI/herdr-gui/releases/download/v${version}/${asset}";
    hash =
      hashes.${system}
        or (throw "herdr-gui: missing hash for ${system} at ${version}");
  };

  # Bun single-file executables break under autoPatchelf; ship as-is (glibc build).
  dontPatchELF = true;
  dontStrip = true;

  # Archive layout: herdr-gui-<platform>/herdr-gui (+ VERSION).
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 */herdr-gui $out/bin/herdr-gui
    runHook postInstall
  '';

  meta = {
    description = "Self-hosted web GUI for Herdr (browser dashboard over the local socket)";
    homepage = "https://github.com/powerfooI/herdr-gui";
    license = lib.licenses.mit;
    mainProgram = "herdr-gui";
    platforms = lib.attrNames assetMap;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
