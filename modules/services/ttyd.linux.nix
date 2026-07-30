{ pkgs, lib, config, env, ... }:
let
  cfg = config.my.services.ttyd;
  inherit (cfg) port;
  portStr = toString port;
in
{
  options.my.services.ttyd = {
    enable = lib.mkEnableOption "ttyd web terminal";
    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
    };
  };

  config = lib.mkIf cfg.enable {
    services.ttyd = {
      enable = true;
      inherit port;
      interface = "127.0.0.1";
      inherit (env) user;
      writeable = true;
      entrypoint = [ (lib.getExe pkgs.zsh) ];
    };

    systemd.services.ttyd.path = [ pkgs.zsh ];

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-ttyd-up" ''
        tailscale serve --service=svc:ttyd --https=443 http://127.0.0.1:${portStr}
      '')
      (writeShellScriptBin "tailscale-svc-ttyd-down" ''
        tailscale serve clear svc:ttyd
      '')
    ];

    my.services.homepage.services."ttyd" = {
      description = "Web terminal";
      href = "https://ttyd.dinosaur-crocodile.ts.net";
    };
  };
}
