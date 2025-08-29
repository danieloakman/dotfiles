{ env, ... }: {
  services.firefly-iii = {
    enable = true;
    enableNginx = true;
    settings = {
      APP_KEY_FILE = "/home/${env.user}/Sync/secrets/firefly-3/app-key.txt";
    };
  };
}
