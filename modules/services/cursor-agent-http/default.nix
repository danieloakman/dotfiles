{ config, pkgs, lib, ... }:
let
  host = "0.0.0.0";
  port = 8222;
  src = ./.;
  cursorAgentBin = lib.getExe pkgs.cursor-cli;
in
{
  users = {
    groups.cursor-agent-http = { };
    users.cursor-agent-http = {
      isSystemUser = true;
      group = "cursor-agent-http";
      extraGroups = [ "secrets" ];
    };
  };

  systemd.services.cursor-agent-http = {
    description = "Cursor-agent OpenAI-compatible HTTP API";
    after = [
      "network.target"
      "sops-nix.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      User = "cursor-agent-http";
      Group = "cursor-agent-http";
    };

    path = with pkgs; [
      bun
      cursor-cli
    ];

    environment = {
      PORT = toString port;
      HOST = host;
      CURSOR_AGENT_BIN = cursorAgentBin;
      CURSOR_AGENT_MODEL_ID = "cursor-agent";
      CURSOR_AGENT_TIMEOUT = "300";
    };

    script = ''
      export CURSOR_API_KEY="$(cat ${config.sops.secrets.cursor_api_key.path})"
      cd ${src}
      exec bun start
    '';
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
