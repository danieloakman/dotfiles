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
    nodejs_24
    # yarn
    pnpm
    pnpm-shell-completion
    bun

    # Golang & related tools:
    go
    gopls
    delve

    # OpenJDK 21 (as of time of this comment):
    zulu
    jre8

    # Fly.io control:
    flyctl

    python3
    (python3.withPackages (ps: with ps; [
      # TODO: comment out most of this in favour of using a nix shell and locally installed packages instead
      pip
      requests
      black
      urllib3
      virtualenv
      # pipx
    ]))

    awscli2
    mprocs
    pet # CLI tool for keeping a list of commands and executing them later
    entr # Run some command when file(s) change

    # AI tools:
    gemini-cli
    claude-code

    # Nix shells:
    (pkgs.buildFHSEnv {
      name = "sh-fhs";
      targetPkgs = pkgs: (with pkgs; [
        tesseract
        python3
        (python3.withPackages (ps: with ps; [
          pip
          virtualenv
          # pipx
        ]))
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
      profile = ''
        # Required for prisma:
        export PRISMA_QUERY_ENGINE_BINARY=/usr/bin/query-engine;
        export PRISMA_SCHEMA_ENGINE_BINARY=/usr/bin/schema-engine;
      '';
      runScript = "zsh";
    })
  ];
}
