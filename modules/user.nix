# Configurations for all users and their home-manager setups:

{ config, lib, pkgs, modulesPath, ... }:
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
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    # User specific packages:
    # packages = with pkgs; [ ];
  };
}
