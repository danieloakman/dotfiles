{ env, pkgs, ... }:
let
  port = 5678;
  # userDir = "/var/lib/n8n";
in
{
  services.n8n = {
    enable = true;
    openFirewall = true;
    environment = {
      N8N_PORT = port;
      N8N_SKIP_AUTH_ON_OAUTH_CALLBACK = true;
      N8N_LOG_LEVEL = "debug";
      WEBHOOK_URL = "https://n8n.dinosaur-crocodile.ts.net";
      # N8N_USER_FOLDER = lib.mkForce userDir; # Got errors saying this dir is read only and it's set multiple times
      NODE_FUNCTION_ALLOW_EXTERNAL = "cheerio";
      # NODES_EXCLUDE = "[]"; # Allow all nodes to be used by default, including the "Execute Command" node.
      # N8N_RUNNERS_ENABLED = false; # Disables task runners, which also disables the ability to run code in python nodes.
    };
  };

  users = {
    groups.n8n = { };
    users.n8n = {
      isSystemUser = true;
      group = "n8n";
      extraGroups = [
        # Allow the n8n user to access secrets:
        "secrets"
      ];
    };
  };

  systemd.services.n8n.path = with pkgs; [
    # Needed for the n8n service to work:
    nodejs_24
    python3
    coreutils

    # Wrap the cursor-agent command with our cursor api key.
    # Didn't end up working as the Execute Command node would just hang when cursor-agent was used.
    # (writeShellScriptBin "cursor-agent" ''
    #   CURSOR_API_KEY="$(cat ${config.sops.secrets.cursor_api_key.path})"
    #   ${lib.getExe pkgs.cursor-cli} --api-key "$CURSOR_API_KEY" --workspace ${userDir} "$@"
    # '')
  ];

  # Install npm packages for n8n Code nodes (allowed via NODE_FUNCTION_ALLOW_EXTERNAL):
  systemd.services.n8n.preStart = ''
    ${pkgs.nodejs_24}/bin/npm install cheerio --prefix /var/lib/n8n
  '';

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-n8n-up" ''
      tailscale serve --service=svc:n8n --https=443 127.0.0.1:${toString port}
    '')
    (writeShellScriptBin "tailscale-svc-n8n-down" ''
      tailscale serve clear svc:n8n
    '')
  ];

  home-manager.users.${env.user} = {
    xdg.desktopEntries =
      let
        webapp = url: "uwsm app -- vivaldi --ozone-platform=wayland --app=\"${url}\"";
      in
      {
        n8n = {
          name = "N8N Automation Platform";
          exec = webapp "http://localhost:${toString port}";
          categories = [ "Network" "WebBrowser" ];
          icon = "vivaldi";
          startupNotify = true;
        };
      };
  };
}
