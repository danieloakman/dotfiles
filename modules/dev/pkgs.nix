# Settings for general developer tools and other related things that only apply to using the system as a developer.

{ pkgs, lib, config, env, ... }:
let
  cfg = config.my.dev.pkgs;
in
{
  options.my.dev.pkgs.enable = lib.mkEnableOption "Enable and include developer packages in the system environment";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    any = {
      environment.systemPackages = with pkgs; [
        nixpkgs-fmt
        statix
        nil
        nodejs_24
        bun
        pnpm
        pnpm-shell-completion
        pet # CLI tool for keeping a list of commands and executing them later
        entr
        ripgrep # We could use the home-manager ripgrep package instead if we needed to give it some specific arguments everytime

        # Golang & related tools:
        go
        gopls
        delve
      ];
    };
    linux = {
      environment.systemPackages = with pkgs; [
        # rclone # Don't need anymore as it was just used for Obsidian syncing
        gnat13 # Provides gcc, g++, etc
        # libgcc # Unsure why this doesn't gives gcc, g++, etc as programs to use, but it don't
        gnumake
        just # Task runner, like `make`
        nurl # Generates nix fetcher urls
        dust # A better `du` command. Just prints out size of directories in the CWD
        ncdu # Similar to `dust`, but provides a UI to delete directories
        tldr
        zbar # Can scan QR & bar codes using this
        lf # Terminal file system manager
        wine # For running Windows applications on Linux
        nix-prefetch-github

        # yarn

        # OpenJDK 21 (as of time of this comment):
        zulu
        jre8

        # Fly.io control:
        flyctl

        awscli2
        mprocs
        entr # Run some command when file(s) change

        # Editors that can be ssh'd into and used:
        vscode

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
          ]) ++ (with pkgs; [
            libx11
            libxext
            libsm
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
    };

    # darwin = {
    #   environment.systemPackages = with pkgs; [
    #   ];
    # };
  });
}
