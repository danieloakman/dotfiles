{ config, lib, env, pkgs, ... }:
let
  cfg = config.my.programs.localsend;

  # Official LocalSend HTTPS requires mutual TLS. Upstream jocalsend's reqwest
  # client accepts peer certs but never presents ours, so prepare-upload/register
  # fail with TLSV1_ALERT_CERTIFICATE_REQUIRED against current LocalSend apps.
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
