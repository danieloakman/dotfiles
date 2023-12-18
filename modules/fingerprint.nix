# Fingerprint scanning.

{ inputs, config, lib, pkgs, modulesPath, ... }:
{
  services.fprintd = {
    enable = true;
    package = pkgs.fprintd-tod;
    tod = {
      enable = true;
      driver = pkgs.libfprint-2-tod1-goodix;
    };
  };
}