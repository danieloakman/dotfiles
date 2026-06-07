{ env, config, lib, ... }:
let
  cfg = config.my.programs.claude-code;
in
{
  options.my.programs.claude-code.enable = lib.mkEnableOption "Enable and configure Claude Code.";

  config = lib.mkMerge [
    {
      my.programs.claude-code.enable = lib.mkDefault config.my.dev.ai.enable;
    }
    (lib.mkIf cfg.enable {
      home-manager.users.${env.user} = {
        programs.claude-code = {
          # Boethiah installs claude-code via Homebrew; npm registry is blocked on darwin hosts.
          enable = env.platform != "darwin";
          # Avoid telemetry 404s when using claude-local (ANTHROPIC_BASE_URL → local llama-server)
          settings = {
            env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
            includeCoAuthoredBy = false;
            theme = "dark";
            effortLevel = "high"; # Ideally it'd be nice for us to be able to change this ourselves with /effort, but high is alright for now.
          };
          rules = {
            response-to-user = ''
              When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
            '';
          };
        };
      };
    })
  ];
}
