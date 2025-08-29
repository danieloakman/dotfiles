{ env, ... }: {
  services.firefly-iii = {
    enable = true;
    settings = {
      APP_KEY_FILE = "/home/${env.user}/Sync/secrets/firefly-3/app-key.txt";
    };
  };
}
