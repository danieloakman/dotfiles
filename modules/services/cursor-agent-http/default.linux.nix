{ config, pkgs, lib, env, ... }:
let
  src = ./.;
  cursorAgentBin = lib.getExe config.my.programs.cursor.agent.package;
in
{
  options.my.services.cursorAgentHttp = {
    enable = lib.mkEnableOption "Enable the Cursor-agent OpenAI-compatible HTTP API";
    port = lib.mkOption {
      type = lib.types.int;
      default = 8222;
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
  };

  config = lib.mkIf config.my.services.cursorAgentHttp.enable {
    assertions = [
      {
        assertion = config.my.programs.cursor.agent.enable;
        message = "my.services.cursorAgentHttp.enable requires my.programs.cursor.agent.enable.";
      }
    ];

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
        config.my.programs.cursor.agent.package
      ];

      environment = {
        PORT = toString config.my.services.cursor-agent-http.port;
        HOST = config.my.services.cursor-agent-http.host;
        CURSOR_AGENT_BIN = cursorAgentBin;
        CURSOR_AGENT_MODEL_ID = "cursor-agent";
        CURSOR_AGENT_TIMEOUT = "300";
      };

      script = ''
        # export here so only the script has the api_key
        export CURSOR_API_KEY="$(cat ${config.sops.secrets.cursor_api_key.path})"
        cd ${src}
        exec bun start
      '';
    };

    networking.firewall.allowedTCPPorts = [ config.my.services.cursor-agent-http.port ];
  };
}
