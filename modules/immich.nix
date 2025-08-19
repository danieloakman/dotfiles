{ env, pkgs, ... }:
let
  user = "immich";
  group = "immich";
  port = 2283;
in
{
  services.immich = {
    inherit user group port;
    enable = true;
    openFirewall = true;
    accelerationDevices = null;
    mediaLocation = "/run/media/HDD_3/immich";
  };

  users.users = {
    ${user} = {
      extraGroups = [ "video" "render" ];
    };
    ${env.user} = {
      extraGroups = [ group "video" "render" ];
    };
  };

  environment.systemPackages = with pkgs; [
    immich-cli
  ];

  networking.firewall.allowedTCPPorts = [ port ];
}
