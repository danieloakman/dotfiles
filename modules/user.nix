# Configurations for all users and their home-manager setups:

{ inputs, config, lib, pkgs, modulesPath, ... }:
{
  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      dano = import ./home.dano.nix;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.dano = {
    isNormalUser = true;
    description = "Daniel Oakman";
    extraGroups = [
      "networkmanager"
      "wheel"
      "adbusers" # Allows access to using `adb`
      "uinput"
    ];
    shell = pkgs.zsh;
    # User specific packages:
    # packages = with pkgs; [ ];

    # This would be needed if we decide to authenticate with public keys instead of passwords:
    # openssh.authorizedKeys.keys = [
    #   "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCH/B3GF0EynMKOXHDcQLG1NDPQwgKqith6wec7rmMHq7rVANn3iM7p85ZzoeXAWVgYloszX5HFv49nqVmaG93Bzr8R9HBHl7lW3Kee8TpGczy+1wywStXU7ldJ+PjJhrSQvpE9Znyekro4M4Div2bEPML/MRFKq/ZQLB6owF2470dNnP0w+xOIGJlACNTSNDblGcfomUFqZzqOY7/EOUwiJchEAqMmozdOJ3uqH6ev3TgGEdXMsVo8ikPFgz7gnVCMOBbHpW3fyf/EFHkIDhv+SO4NE6qp3oMB1e3qfWFdGRORzCq77kn0f7uZID4xad84JQi2kj4ldfp7oTC5p3Lsk73cPH35S/FjO0JEPoZVPa74NBQJY4QQs9ngwHOqV2USLRLJg5cVsyIp9npBi/4ifKZPo1rkFtE969C/oX4XLrKdn65itjmt24FcW4ojlbMnxqWs/KFbmsGIAD9mcUDPAAA8YIDuBMR29naV/LTC8vIg7/h0/d5CbSb7Kvyc+6k= doakman94@gmail.com"
    # ];
  };
}
