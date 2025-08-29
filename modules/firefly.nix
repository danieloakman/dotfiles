{ ... }: {
  services.firefly-iii = {
    enable = true;
    settings = {
      APP_KEY_FILE = "~/Sync/secrets/firefly-3/app-key.txt";
    };
  };
}
