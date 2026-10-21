# T3 Code — minimal web GUI for coding agents.
# https://t3.codes
#
# Tailnet access is the desktop server's own port on each machine
# (http://<magicdns>:3773), not a Tailscale Service name. A shared svc: name
# can only point at one host, and the phone should add each computer itself.
{ env, config, lib, pkgs, ... }:
let
  cfg = config.my.programs.t3code;
  # Desktop scans upward from this port. The firewall hole matches the first
  # choice; a busy 3773 makes the app move and this rule miss it.
  tailnetPort = 3773;
  desktopSettings = "${env.home}/.t3/userdata/desktop-settings.json";
  # lib.hm exists only inside the Home Manager module, not NixOS lib.
  networkAccessActivation = ''
    settings=${lib.escapeShellArg desktopSettings}
    $DRY_RUN_CMD mkdir -p "$(dirname "$settings")"
    if [ ! -f "$settings" ] || [ ! -s "$settings" ]; then
      current='{}'
    else
      current=$(cat "$settings")
    fi
    updated=$(printf '%s\n' "$current" | ${lib.getExe pkgs.jq} '.serverExposureMode = "network-accessible"')
    tmp=$(mktemp)
    printf '%s\n' "$updated" > "$tmp"
    $DRY_RUN_CMD mv "$tmp" "$settings"
  '';
in
{
  options.my.programs.t3code = {
    enable = lib.mkEnableOption ''
      T3 Code (t3code): install via Home Manager's programs.t3code
    '';

    tailnet.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Bind the desktop server on all interfaces and open TCP ${toString tailnetPort}
        on tailscale0 only. LAN and public interfaces stay closed.
        Reach a machine at http://<its MagicDNS name>:${toString tailnetPort}
        while the T3 Code app is running. Restart the app after this changes;
        it reads ~/.t3/userdata/desktop-settings.json on startup.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home-manager.users.${env.user} = { lib, ... }: {
        programs.t3code.enable = true;

        home.activation = lib.mkIf cfg.tailnet.enable {
          t3codeNetworkAccess = lib.hm.dag.entryAfter [ "writeBoundary" ] networkAccessActivation;
        };
      };
    }
    (lib.mkIf cfg.tailnet.enable (env.selectPlatform {
      linux = {
        # Explicit on tailscale0 so this survives a change to trustedInterfaces.
        networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ tailnetPort ];
      };
    }))
  ]);
}
