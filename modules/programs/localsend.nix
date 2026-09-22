{ config, lib, env, pkgs, ... }:
let
  cfg = config.my.programs.localsend;

  # Upstream jocalsend: (1) binds UDP to the unicast LAN IP so it never receives
  # multicast discovery on 224.0.0.167; (2) HTTPS client never presents our
  # device cert, so register/prepare-upload fail mTLS against official apps.
  jocalsend = pkgs.jocalsend.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/jocalsend-mtls-client-cert.patch
    ];
  });
in
{
  options.my.programs.localsend.enable = lib.mkEnableOption "Enable and install localsend, a free alternative to airdrop.";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      environment.systemPackages = [
        jocalsend # Rust based TUI for localsend
      ];
      programs.localsend = {
        enable = true;
        openFirewall = true;
      };
    };
    darwin.homebrew.casks = [ "localsend" ];
  });
}
