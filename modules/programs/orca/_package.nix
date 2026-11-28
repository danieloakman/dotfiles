# Orca ADE — pinned Linux AppImage, extracted + autoPatchelf (no bwrap/FHS).
# https://orca.dev/ · https://github.com/stablyai/orca/releases
#
# Avoid appimageTools.wrapType2: its FHS bubblewrap sets PR_SET_NO_NEW_PRIVS, so
# every terminal PTY Orca spawns inherits NoNewPrivileges and sudo/nh fail.
#
# Bump version + both hashes together (and the skills source hash in default.nix):
#   nix store prefetch-file "https://github.com/stablyai/orca/releases/download/vVERSION/orca-linux.AppImage"
#   nix store prefetch-file "https://github.com/stablyai/orca/releases/download/vVERSION/orca-linux-arm64.AppImage"
{ lib
, stdenv
, fetchurl
, appimageTools
, autoPatchelfHook
, makeWrapper
, wrapGAppsHook3
, alsa-lib
, at-spi2-atk
, at-spi2-core
, cairo
, cups
, dbus
, expat
, glib
, gtk3
, libdrm
, libgbm
, libGL
, libxkbcommon
, mesa
, nspr
, nss
, pango
, udev
, vulkan-loader
, libx11
, libxcomposite
, libxdamage
, libxext
, libxfixes
, libxrandr
, libxcb
, version ? "1.4.281"
,
}:
let
  pname = "orca-ide";

  src =
    fetchurl
      {
        x86_64-linux = {
          url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
          hash = "sha256-TPdIy1s2Ch9TKEWtiPz1SpkEUnSumU/E2RS3Opi52JM=";
        };
        aarch64-linux = {
          url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux-arm64.AppImage";
          hash = "sha256-MPblEfc3P7xhi67xNlZVrYcfmthBovaoggCqONDEjG4=";
        };
      }.${stdenv.hostPlatform.system}
        or (throw "orca-ide: unsupported system ${stdenv.hostPlatform.system}");

  appimageContents = appimageTools.extract { inherit pname version src; };

  # Libs Electron / Chromium NEEDED + common dlopens (GL/Vulkan).
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    udev
    vulkan-loader
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  src = appimageContents;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  # Optional musl build of koffi shipped alongside the glibc one.
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
  ];

  # Only wrap the GUI binary; leave `orca` (CLI shell script) alone.
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${pname} $out/bin $out/share/applications
    # Preserve +x from the AppImage extract (store files are often 0555).
    cp -a ${appimageContents}/. $out/lib/${pname}/
    chmod -R u+w $out/lib/${pname}

    # Drop AppImage FHS leftovers (old libappindicator/gconf). We link against
    # nixpkgs GTK/etc. via autoPatchelf instead.
    rm -rf $out/lib/${pname}/usr/lib

    # CLI entry (ELECTRON_RUN_AS_NODE). Keep path relative to resources/; expose
    # as `orca` so it does not collide with the GUI wrapper.
    if [ -x $out/lib/${pname}/resources/bin/orca-ide ]; then
      ln -s ../lib/${pname}/resources/bin/orca-ide $out/bin/orca
    fi

    desktop=""
    for candidate in orca-ide.desktop orca.desktop; do
      if [ -f $out/lib/${pname}/$candidate ]; then
        desktop=$candidate
        break
      fi
    done
    if [ -n "$desktop" ]; then
      install -Dm444 $out/lib/${pname}/$desktop $out/share/applications/orca-ide.desktop
      substituteInPlace $out/share/applications/orca-ide.desktop \
        --replace-quiet 'Exec=AppRun --no-sandbox' 'Exec=orca-ide' \
        --replace-quiet 'Exec=AppRun' 'Exec=orca-ide'
    fi

    if [ -d $out/lib/${pname}/usr/share/icons ]; then
      mkdir -p $out/share/icons
      cp -a $out/lib/${pname}/usr/share/icons/. $out/share/icons/
    fi

    runHook postInstall
  '';

  # chrome-sandbox cannot be setuid in the store. makeBinaryWrapper cannot do
  # shell ''${NIXOS_OZONE_WL:+...} expansion — pass stable flags only.
  postFixup = ''
    makeWrapper $out/lib/${pname}/orca-ide $out/bin/orca-ide \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}:$out/lib/${pname} \
      --add-flags --no-sandbox \
      --add-flags --ozone-platform-hint=auto \
      --inherit-argv0
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
