# ArtCraft crafting apps — pinned Linux release tarballs from storytold/*.
# https://getartcraft.com/apps
#
# Prefetch after a version bump (hex digests are also in each release's SHA256SUMS):
#   nix hash convert --hash-algo sha256 --to sri HEX
#   # or: nix store prefetch-file URL
{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  autoAddDriverRunpath,
  alsa-lib,
  libxkbcommon,
  wayland,
  vulkan-loader,
  xorg,
}:
let
  inherit (stdenv.hostPlatform) system;

  linuxArch =
    {
      x86_64-linux = "x86_64";
      aarch64-linux = "aarch64";
    }
    .${system} or (throw "artcraft: unsupported system ${system}");

  # Libraries the apps dlopen at runtime (wgpu / winit). Same set as upstream
  # lightcraft's nix/package.nix wrapper.
  runtimeLibs = [
    libxkbcommon
    wayland
    xorg.libX11
    xorg.libxcb
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    vulkan-loader
  ];

  # Bump version + both hashes together when updating an app.
  apps = {
    photocraft = {
      version = "0.5.0";
      description = "Image editor; clean-room Photoshop reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/photocraft";
      hashes = {
        x86_64-linux = "sha256-4EQQGy2lUiiW4dgza4EIfL7L9reLdoUxX1jdTz36TOA=";
        aarch64-linux = "sha256-OQT8nKtFsIPVhwqNT6uQs6lMO6VUemNrt79aOY2pxVI=";
      };
    };
    lightcraft = {
      version = "0.4.0";
      description = "Photo library and raw developer; clean-room Lightroom reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/lightcraft";
      hashes = {
        x86_64-linux = "sha256-wsdXgLzwWKIcSjEc5X20flnwrC9t1wRYM3aa4QA7VyM=";
        aarch64-linux = "sha256-adhCWwswyXOizAcrJc+QMQgcFEvEPlK3zqci656KgQA=";
      };
    };
    filmcraft = {
      version = "0.4.0";
      description = "Video editor; clean-room Premiere Pro reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/filmcraft";
      hashes = {
        x86_64-linux = "sha256-hBeQ/2ZJ8NSdqkqK3hyxjZSOXKQ9AHcQRmY+BsjYzoM=";
        aarch64-linux = "sha256-P7/JtJoCv6imumvX8YQXc7Ymoq3wkY9eYWQpnT8S8UQ=";
      };
    };
    pdfcraft = {
      version = "0.4.0";
      description = "PDF viewer and editor; clean-room Acrobat reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/pdfcraft";
      hashes = {
        x86_64-linux = "sha256-SHmzzbTRJhlFrwOxxfAPPoaNBehOd5EZYMrFBaoWwds=";
        aarch64-linux = "sha256-CLL/bFOK2zzAioiBSjzObu4Jy5jJr5NMOTpRMaMVWQ4=";
      };
    };
    vectorcraft = {
      version = "0.7.0";
      description = "Vector graphics; clean-room Illustrator reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/vectorcraft";
      hashes = {
        x86_64-linux = "sha256-1rDuV+G9vTd7RMhSToVprStN/0a3kvwQsO2/jXQpKs0=";
        aarch64-linux = "sha256-JfVfZOnoRFqrfnNEDeS+J5T3+u4s1yn4ydZrxzF3FSU=";
      };
    };
    effectcraft = {
      version = "0.6.0";
      description = "Motion graphics and VFX; clean-room After Effects reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/effectcraft";
      hashes = {
        x86_64-linux = "sha256-cYEHGZAzeM2rMqH+Mo8jyHTTjNPYM6uxnGJj3SutIYw=";
        aarch64-linux = "sha256-d8xXa5sce2Q26ZfySoxQsFeD9svlc6rqoOx+EFh3RY4=";
      };
    };
    designcraft = {
      version = "0.4.0";
      description = "Page layout and publishing; clean-room InDesign reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/designcraft";
      hashes = {
        x86_64-linux = "sha256-TAtowNxiCB5FW/jWDdVPAi/xYkNZ1eENBsorGNc9S7M=";
        aarch64-linux = "sha256-G1uQVpWa2lKQqizarYUHSMn58JocO0E2kIurmWsrtFw=";
      };
    };
    wordcraft = {
      version = "0.3.0";
      description = "Word processor; clean-room Microsoft Word reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/wordcraft";
      hashes = {
        x86_64-linux = "sha256-wLOkthr+DoiRsThvc9yUrfUo2NhzYPP7cal7oDOBrsI=";
        aarch64-linux = "sha256-w72WTnPnzSxVap0OugSs1BrvrI28457HIjNgp9H7zTY=";
      };
    };
    cadcraft = {
      version = "0.3.0";
      description = "CAD drafting; clean-room AutoCAD-style app in Rust";
      homepage = "https://getartcraft.com/apps/cadcraft";
      hashes = {
        x86_64-linux = "sha256-QjmwVFwABsE/ZBn+m8IEYtcnCWkSzzyx6yUjk0ECvXg=";
        aarch64-linux = "sha256-7hTByZ4JK0b27+foCdSp6kGnekNtId3S81rj8VQpNWM=";
      };
    };
    gridcraft = {
      version = "0.3.0";
      description = "Spreadsheet; clean-room Excel-style app in Rust";
      homepage = "https://getartcraft.com/apps/gridcraft";
      hashes = {
        x86_64-linux = "sha256-5RWuiK4kgKBKS10klUDugqxSHQvouGu8qPVlR7yBVP8=";
        aarch64-linux = "sha256-wgDPavK12pkjnxDoNqbnrZxNxMUMpEmDcA0dlgv1Dis=";
      };
    };
    soundcraft = {
      version = "0.3.0";
      description = "Audio workstation; clean-room Pro Tools reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/soundcraft";
      hashes = {
        x86_64-linux = "sha256-MdSj5O/oiqRykbK1qoXkVnn9c5iOuVEBXdsk6yu6kyI=";
        aarch64-linux = "sha256-pNi9qrfxM0OEPIwvpI8jiVQ/+nToc1i7mpsVWWBeZgs=";
      };
    };
    deckcraft = {
      version = "0.3.0";
      description = "Presentations; clean-room PowerPoint reimplementation in Rust";
      homepage = "https://getartcraft.com/apps/deckcraft";
      hashes = {
        x86_64-linux = "sha256-F51s5HQBujfCM8P8ChgDQSau2BrDaknE327NrKm1q38=";
        aarch64-linux = "sha256-/h2TbH5nNxq6Lj7Yb/6bwgcgpuH/Wwo5DIIoO7lMJD8=";
      };
    };
  };

  mkCraftApp =
    pname:
    {
      version,
      description,
      homepage,
      hashes,
    }:
    let
      archiveStem = "${pname}-${version}-linux-${linuxArch}";
    in
    stdenv.mkDerivation {
      inherit pname version;

      src = fetchurl {
        url = "https://github.com/storytold/${pname}/releases/download/v${version}/${archiveStem}.tar.gz";
        hash =
          hashes.${system} or (throw "artcraft.${pname}: missing hash for ${system} at ${version}");
      };

      sourceRoot = archiveStem;

      nativeBuildInputs = [
        autoPatchelfHook
        autoAddDriverRunpath
        makeWrapper
      ];

      # Release binaries link libgcc_s / libasound; autoPatchelf needs them on
      # the buildInputs path (soundcraft, filmcraft, effectcraft, deckcraft).
      buildInputs = [
        stdenv.cc.cc
        alsa-lib
      ];

      dontStrip = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -a bin share $out/
        runHook postInstall
      '';

      postFixup = ''
        for bin in $out/bin/*; do
          wrapProgram "$bin" --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"
        done
      '';

      meta = {
        inherit description homepage;
        license = with lib.licenses; [
          mit
          asl20
        ];
        mainProgram = pname;
        platforms = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };
in
lib.mapAttrs mkCraftApp apps
