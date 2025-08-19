{ env, pkgs, ... }: {
  services.immich = {
    enable = true;
    openFirewall = true;
    accelerationDevices = null;
    mediaLocation = "/run/media/HDD_3/immich";
    group = "immich";
  };
  users.users.${env.user} = {
    extraGroups = [ "immich" ];
  };
  environment.systemPackages = with pkgs; [
    immich-cli
  ];
}
