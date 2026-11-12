# Superwhisper for Linux — pinned portable release tarball.
# https://tux.superwhisper.com/stable.json
# https://github.com/superultrainc/superwhisper-linux-releases
#
# Upstream's Nix flake (github:superultrainc/superwhisper-linux) is not public yet;
# bump version + hashes here from stable.json when updating.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  autoAddDriverRunpath,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  vulkan-loader,
  gtk4,
  gtk4-layer-shell,
  gdk-pixbuf,
  cairo,
  graphene,
  glib,
  fontconfig,
  libxkbcommon,
  wayland,
  xorg,
  python3,
  wl-clipboard,
  libnotify,
  ffmpeg,
  at-spi2-core,
  fcitx5,
}:
let
  inherit (stdenv.hostPlatform) system;

  version = "1.3.1";

  arch =
    {
      x86_64-linux = "x86_64";
      aarch64-linux = "aarch64";
    }
    .${system} or (throw "superwhisper: unsupported system ${system}");

  hashes = {
    x86_64-linux = "sha256-RkpzLKbJKNPyuLuUaHF2p1yisJwYYzPTTZTQUcy18OQ=";
    aarch64-linux = "sha256-pEDIXqMb2ww8Oz3pcaBCQCzGmO+ifFTcVzyVU/0o8G8=";
  };

  runtimeLibs = [
    stdenv.cc.cc.lib
    vulkan-loader
    gtk4
    gtk4-layer-shell
    gdk-pixbuf
    cairo
    graphene
    glib
    fontconfig
    libxkbcommon
    wayland
    xorg.libxcb
    xorg.libX11
    fcitx5
  ];

  pythonEnv = python3.withPackages (
    ps: with ps; [
      pygobject3
      pycairo
    ]
  );

  pathBins = [
    pythonEnv
    wl-clipboard
    libnotify
    ffmpeg
    at-spi2-core
  ];
in
stdenv.mkDerivation {
  pname = "superwhisper";
  inherit version;

  src = fetchurl {
    url = "https://tux.superwhisper.com/${arch}/v${version}/superwhisper-omarchy-${arch}-${version}.tar.zst";
    hash = hashes.${system};
  };

  sourceRoot = "superwhisper-omarchy-${arch}-${version}";

  nativeBuildInputs = [
    autoPatchelfHook
    autoAddDriverRunpath
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = runtimeLibs;

  dontStrip = true;

  desktopItems = [
    (makeDesktopItem {
      name = "com.superwhisper.Superwhisper";
      desktopName = "Superwhisper";
      comment = "Fast local and cloud dictation";
      exec = "superwhisper settings --window";
      icon = "superwhisper";
      startupWMClass = "com.superwhisper.Superwhisper";
      categories = [
        "Utility"
        "Accessibility"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/superwhisper
    cp -a app/. $out/lib/superwhisper/

    # run.sh expects libonnxruntime.so; the archive ships a versioned SONAME only.
    ln -sfn libonnxruntime.so.1.24.2 $out/lib/superwhisper/lib/libonnxruntime.so

    mkdir -p $out/bin
    makeWrapper $out/lib/superwhisper/run.sh $out/bin/superwhisper \
      --prefix PATH : ${lib.makeBinPath pathBins} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --set SUPERWHISPER_UPDATE_DISABLED 1 \
      --set ORT_DYLIB_PATH $out/lib/superwhisper/lib/libonnxruntime.so

    # hicolor icons from the release app-icon set
    for size in 16 32 64 128 256 512 1024; do
      install -Dm644 app/assets/app-icon/$size.png \
        $out/share/icons/hicolor/''${size}x''${size}/apps/superwhisper.png
    done

    runHook postInstall
  '';

  meta = {
    description = "Voice-to-text dictation for Wayland (local Whisper + optional cloud)";
    homepage = "https://superwhisper.com/linux";
    license = lib.licenses.unfree;
    mainProgram = "superwhisper";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
