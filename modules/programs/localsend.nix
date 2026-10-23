{ config, lib, env, pkgs, ... }:
let
  cfg = config.my.programs.localsend;

  # Upstream jocalsend: (1) binds UDP to the unicast LAN IP so it never receives
  # multicast discovery on 224.0.0.167; (2) HTTPS client never presents our
  # device cert, so register/prepare-upload fail mTLS against official apps;
  # (3) upload route caps the body at 1 GiB and buffers it in RAM, so larger
  # files fail with HTTP 413; (4) download_dir is snapshotted to
  # ~/jocalsend-downloads in the toml on first launch.
  jocalsend = pkgs.jocalsend.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/jocalsend-mtls-client-cert.patch
      ./patches/jocalsend-stream-uploads.patch
      ./patches/jocalsend-download-dir.patch
    ];
  });

  # Wrapper only when pinning a directory. The patch saves into the process
  # working directory when JOCALSEND_DOWNLOAD_DIR is unset.
  jocalsendBin =
    if cfg.download-dir == null
    then jocalsend
    else
      pkgs.writeShellScriptBin "jocalsend" ''
        export JOCALSEND_DOWNLOAD_DIR=${lib.escapeShellArg cfg.download-dir}
        exec ${lib.getExe jocalsend} "$@"
      '';
in
{
  options.my.programs.localsend = {
    enable = lib.mkEnableOption "Enable and install localsend, a free alternative to airdrop.";

    download-dir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/dano/Downloads";
      description = ''
        Absolute directory where jocalsend saves received files.
        Null saves into the directory the command was started from.
        Applies to the Linux jocalsend package. The download_dir entry in
        ~/.config/jocalsend.toml is ignored.
      '';
    };
  };

  config = lib.mkIf cfg.enable (env.selectPlatform {
    any.assertions = lib.optional (cfg.download-dir != null) {
      assertion = lib.hasPrefix "/" cfg.download-dir;
      message = "my.programs.localsend.download-dir must be an absolute path";
    };
    linux = {
      environment.systemPackages = [
        jocalsendBin # Rust based TUI for localsend
      ];
      programs.localsend = {
        enable = true;
        openFirewall = true;
      };
    };
    darwin.homebrew.casks = [ "localsend" ];
  });
}
