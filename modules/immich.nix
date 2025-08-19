{ env, ... }: {
  services.immich = {
    enable = true;
    user = env.user;
    openFirewall = true;
    accelerationDevices = null;
    mediaLocation = "/run/media/HDD_3/immich";
  };
}
