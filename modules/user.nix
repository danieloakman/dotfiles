# Configurations for all users and their home-manager setups:

{ inputs, pkgs, env, ... }:
{
  home-manager = {
    extraSpecialArgs = { inherit inputs env; };
    users = {
      ${env.user} = import ./home.${env.user}.nix;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${env.user} = {
    isNormalUser = true;
    description = "Daniel Oakman";
    extraGroups = [
      "networkmanager"
      "wheel"
      "adbusers" # Allows access to using `adb`
      "uinput"
      "video" # Possible fix for djo-laptop-tiny cam not working
    ];
    shell = pkgs.zsh;
    # User specific packages:
    # packages = with pkgs; [ ];

    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCH/B3GF0EynMKOXHDcQLG1NDPQwgKqith6wec7rmMHq7rVANn3iM7p85ZzoeXAWVgYloszX5HFv49nqVmaG93Bzr8R9HBHl7lW3Kee8TpGczy+1wywStXU7ldJ+PjJhrSQvpE9Znyekro4M4Div2bEPML/MRFKq/ZQLB6owF2470dNnP0w+xOIGJlACNTSNDblGcfomUFqZzqOY7/EOUwiJchEAqMmozdOJ3uqH6ev3TgGEdXMsVo8ikPFgz7gnVCMOBbHpW3fyf/EFHkIDhv+SO4NE6qp3oMB1e3qfWFdGRORzCq77kn0f7uZID4xad84JQi2kj4ldfp7oTC5p3Lsk73cPH35S/FjO0JEPoZVPa74NBQJY4QQs9ngwHOqV2USLRLJg5cVsyIp9npBi/4ifKZPo1rkFtE969C/oX4XLrKdn65itjmt24FcW4ojlbMnxqWs/KFbmsGIAD9mcUDPAAA8YIDuBMR29naV/LTC8vIg7/h0/d5CbSb7Kvyc+6k= doakman94@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILEBLbSD9MCQWRVslpMNVI57u2K03AEp1Qvk9UTqo3jv doakman94@gmail.com"
    ];
  };
}
