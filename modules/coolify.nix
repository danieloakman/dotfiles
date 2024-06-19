# Taken from https://github.com/jankaifer/nixos/blob/ab01ecbc451d3d0400a6e6da90f492b2272389bc/machines/oldbox/default.nix#L802-L844
# I think I would need docker to get this to work.
{ pkgs, config, ...}:
let
  coolify = { port = 8008; };
in
{
  # Add Coolify
  # This key was generated on first start of coolify
  # Coolify needs root login
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPQW4odGjy5ZsIZ6gh4pCes74eFJbb6EbLXDqf8HJyVe root@coolify" ];

  # age.secrets.coolify-env.file = ../../secrets/coolify-env-file.age;
  systemd.services.coolify-prepare-files = {
    description = "Setup files for coolify";
    wantedBy = [ "coolify.service" ];
    wants = [ "data-coolify.mount" ];
    script = ''
      #! ${pkgs.bash}/bin/bash
      NAMES='source ssh applications databases backups services proxy webhooks-during-maintenance ssh/keys ssh/mux proxy/dynamic'
      for NAME in $NAMES
      do
        FOLDER_PATH="/data/coolify/$NAME"
        if [ ! -d "$FOLDER_PATH" ]; then
          mkdir -p "$FOLDER_PATH"
        fi
      done

      cp -f "${./coolify/docker-compose.yml}" /data/coolify/source/docker-compose.yml
      cp -f "${./coolify/docker-compose.prod.yml}" /data/coolify/source/docker-compose.prod.yml
      cp -f "${ config.age.secrets.coolify-env.path }" /data/coolify/source/.env
      cp -f "${./coolify/upgrade.sh}" /data/coolify/source/upgrade.sh

      # Generate SSH key if not ready
      if [ ! -f "/data/coolify/ssh/keys/id.root@host.docker.internal" ]; then
        ssh-keygen -f /data/coolify/ssh/keys/id.root@host.docker.internal -t ed25519 -N "" -C root@coolify
      fi

      chown -R 9999:root /data/coolify
      chmod -R 700 /data/coolify
    '';
  };
  systemd.services.coolify = {
    script = ''
      APP_PORT="${toString coolify.port}" "${pkgs.docker}/bin/docker" compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml up -d --pull always --remove-orphans --force-recreate
    '';
    after = [ "docker.service" "docker.socket" ];
    wantedBy = [ "multi-user.target" ];
  };
}