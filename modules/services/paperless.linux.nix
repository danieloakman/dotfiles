{ lib, config, pkgs, env, ... }:
let
  cfg = config.my.services.paperless;
  inherit (cfg) port;
  hostname = "127.0.0.1";
  user = "paperless";
  localUrl = "http://${hostname}:${toString port}";
  hasApiToken = builtins.hasAttr "paperless_api_token" (config.sops.secrets or { });
  triageCfg = cfg.triage;
  agentsOn = config.my.programs.agents.enable;
  cursorAgentOn = config.my.programs.cursor.agent.enable;
  tokenPath = config.sops.secrets.paperless_api_token.path or "/run/secrets/paperless_api_token";
  cursorAgentExe = lib.getExe config.my.programs.cursor.agent.package;
  dotfilesDir = "${env.home}/repos/personal/dotfiles";

  paperlessManageSkill = pkgs.runCommand "paperless-manage-skill" { } ''
    mkdir -p $out
    cp ${./paperless-manage/reference.md} $out/reference.md
    substitute ${./paperless-manage/SKILL.md} $out/SKILL.md \
      --subst-var-by domain ${lib.escapeShellArg cfg.domain} \
      --subst-var-by user ${lib.escapeShellArg user}
  '';

  paperlessTriageSkill = pkgs.runCommand "paperless-triage-skill" { } ''
    mkdir -p $out
    cp ${./paperless-triage/reference.md} $out/reference.md
    substitute ${./paperless-triage/SKILL.md} $out/SKILL.md \
      --subst-var-by domain ${lib.escapeShellArg cfg.domain} \
      --subst-var-by port ${lib.escapeShellArg (toString port)} \
      --subst-var-by tag ${lib.escapeShellArg triageCfg.tag} \
      --subst-var-by needsReviewTag ${lib.escapeShellArg triageCfg.needs-review-tag} \
      --subst-var-by threshold ${lib.escapeShellArg (toString triageCfg.threshold)}
  '';

  paperlessTriageRun = pkgs.writeShellApplication {
    name = "paperless-triage-run";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      set -euo pipefail

      THRESHOLD=${toString triageCfg.threshold}
      TAG_NAME=${lib.escapeShellArg triageCfg.tag}
      PAPERLESS_URL=${lib.escapeShellArg localUrl}
      TOKEN_FILE=${lib.escapeShellArg tokenPath}
      DOTFILES_DIR=${lib.escapeShellArg dotfilesDir}
      CURSOR_AGENT=${lib.escapeShellArg cursorAgentExe}

      if [[ ! -r "$TOKEN_FILE" ]]; then
        echo "paperless-triage: token file not readable: $TOKEN_FILE" >&2
        exit 1
      fi

      TOKEN="$(tr -d '\n' < "$TOKEN_FILE")"
      if [[ -z "$TOKEN" || "$TOKEN" == "REPLACE_ME" ]]; then
        echo "paperless-triage: set a real paperless_api_token in sops (not REPLACE_ME)" >&2
        exit 1
      fi

      auth_hdr=( -H "Authorization: Token ''${TOKEN}" -H "Accept: application/json" )

      tag_json="$(curl -sf "''${auth_hdr[@]}" "''${PAPERLESS_URL}/api/tags/?name=''${TAG_NAME}")"
      tag_id="$(echo "$tag_json" | jq -r '.results[0].id // empty')"
      if [[ -z "$tag_id" ]]; then
        echo "paperless-triage: tag ''${TAG_NAME} not found; create it and a Document Added workflow" >&2
        exit 0
      fi

      count="$(curl -sf "''${auth_hdr[@]}" \
        "''${PAPERLESS_URL}/api/documents/?tags__id=''${tag_id}&page_size=1" | jq -r '.count')"

      if [[ -z "$count" || "$count" == "null" ]]; then
        echo "paperless-triage: failed to read document count" >&2
        exit 1
      fi

      if (( count < THRESHOLD )); then
        echo "paperless-triage: count=''${count} < ''${THRESHOLD}; skip agent"
        exit 0
      fi

      echo "paperless-triage: count=''${count} >= ''${THRESHOLD}; starting cursor-agent"
      export PAPERLESS_URL PAPERLESS_TOKEN_FILE="$TOKEN_FILE"
      exec "$CURSOR_AGENT" -p --force --trust \
        --workspace "$DOTFILES_DIR" \
        "Follow the paperless-triage skill. Auto-apply. Process documents with the ''${TAG_NAME} tag (queue count was ''${count}). Prefer http://127.0.0.1 for PAPERLESS_URL if on this host. Token file: \$PAPERLESS_TOKEN_FILE."
    '';
  };
in
{
  options.my.services.paperless = {
    enable = lib.mkEnableOption "Enable the Paperless service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 28981;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain to use for the Paperless service";
    };
    media-dir = lib.mkOption {
      type = lib.types.str;
      description = "The directory to use for the Paperless media files";
    };
    agent-skill.enable = lib.mkEnableOption ''
      Install the paperless-manage skill for AI agents (via my.programs.agents).
    '' // {
      default = true;
    };
    triage = {
      enable = lib.mkEnableOption ''
        Install the paperless-triage skill and a user timer that runs cursor-agent
        when at least `threshold` documents have the triage tag.
      '' // {
        default = true;
      };
      threshold = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Minimum triage-tagged document count before starting cursor-agent.";
      };
      tag = lib.mkOption {
        type = lib.types.str;
        default = "triage";
        description = "Paperless tag name used as the AI triage queue.";
      };
      needs-review-tag = lib.mkOption {
        type = lib.types.str;
        default = "needs-review";
        description = "Tag applied when the agent is uncertain about classification.";
      };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "15min";
        description = "systemd OnUnitActiveSec / OnBootSec interval for the triage count check.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.domain != null;
          message = "paperless.domain must be set";
        }
        {
          assertion = cfg.media-dir != null;
          message = "paperless.media-dir must be set";
        }
      ];

      services.paperless = {
        inherit port user;
        enable = true;
        address = hostname;
        inherit (cfg) domain;
      };

      users.users.${user}.extraGroups = [ "storage" ];

      services.tailscale.serve.services.paperless = {
        endpoints."tcp:443" = "http://${hostname}:${toString port}";
      };

      my.services.homepage.services."Paperless" = {
        description = "Document management";
        href = "https://paperless.dinosaur-crocodile.ts.net";
        group = "Documents";
        icon = "paperless-ngx.png";
        widget = {
          type = "paperlessngx";
          url = "http://127.0.0.1:${toString port}";
          username = "{{HOMEPAGE_FILE_PAPERLESS_USERNAME}}";
          password = "{{HOMEPAGE_FILE_PAPERLESS_PASSWORD}}";
          fields = [
            "total"
            "inbox"
          ];
        };
      };

      my.programs.agents.skill-dirs.paperless-manage = lib.mkIf
        (cfg.agent-skill.enable && agentsOn)
        paperlessManageSkill;
    }

    (lib.mkIf triageCfg.enable {
      assertions = [
        {
          assertion = agentsOn;
          message = "my.services.paperless.triage.enable requires my.programs.agents.enable.";
        }
        {
          assertion = cursorAgentOn;
          message = "my.services.paperless.triage.enable requires my.programs.cursor.agent.enable.";
        }
        {
          assertion = hasApiToken;
          message = "my.services.paperless.triage.enable requires sops secret paperless_api_token.";
        }
      ];

      my.programs.agents.skill-dirs.paperless-triage = lib.mkIf agentsOn paperlessTriageSkill;

      users.users.${env.user}.linger = true;

      home-manager.users.${env.user} = {
        home.packages = [ paperlessTriageRun ];

        systemd.user.services.paperless-triage = {
          Unit = {
            Description = "Paperless AI triage (cursor-agent when triage queue >= ${toString triageCfg.threshold})";
            After = [ "network-online.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe paperlessTriageRun;
          };
        };

        systemd.user.timers.paperless-triage = {
          Unit.Description = "Check Paperless triage queue for cursor-agent classification";
          Timer = {
            OnBootSec = triageCfg.interval;
            OnUnitActiveSec = triageCfg.interval;
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    })
  ]);
}
