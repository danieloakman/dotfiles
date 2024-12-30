# Settings for general developer tools and other related things that only apply to using the system as a developer.

{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # rclone # Don't need anymore as it was just used for Obsidian syncing
    gnat13 # Provides gcc, g++, etc
    # libgcc # Unsure why this doesn't gives gcc, g++, etc as programs to use, but it don't
    gnumake
    nurl # Generates nix fetcher urls
    dust # A better `du` command. Just prints out size of directories in the CWD
    ncdu # Similar to `dust`, but provides a UI to delete directories
    tldr
    gcalcli
    zbar # Can scan QR & bar codes using this
    lf # Terminal file system manager

    # Node and Javascript related packages:
    nodejs_22
    # yarn
    pnpm
    pnpm-shell-completion
    bun

    python3
    (python3.withPackages (ps: with ps; [
      # TODO: comment out most of this in favour of using a devenv and locally installed packages instead
      pip
      requests
      black
      urllib3
      virtualenv
      # pipx
    ]))

    awscli2
    mprocs

    # Nix shells:
    (pkgs.buildFHSEnv {
      name = "sh-fhs";
      targetPkgs = pkgs: (with pkgs; [
        # More or less copied from the auxilis FHS shell
        tesseract
        python3
        python3Packages.pip
        python3Packages.virtualenv
        swig
        glibc
        glib.dev
        libffi
        ffmpeg
        libsmf
        libGL
        libz
        libzip
        libgcc
        zlib
        pango
        fontconfig
        # libstdcxx5 Apparently outdated
        opencv
        cmake
        pixman
        cairo
        libjpeg
        giflib
        librsvg
        pkg-config
        # cairomm_1_16

        # Needed for prisma:
        openssl
        prisma-engines
      ]) ++ (with pkgs.xorg; [
        libX11
        libXext
        libSM
      ]);
      # nativeBuildInputs = pkgs: (with pkgs; [
      #   pkg-config
      # ]);
      # multiPkgs = pkgs: (with pkgs; [
      #   # Nothing for now
      # ]);
      runScript = "zsh";
    })
  ];
}
