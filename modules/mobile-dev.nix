# Development stuff for mobile dev:
{ config, pkgs, ... }:
{
  programs = {
    # Enable Android Debug Bridge:
    adb.enable = true;
  };
  environment.systemPackages = with pkgs; [
    android-studio
    android-tools
  ];
  home-manager.users.${config.env.user}.home = /* { lib, pkgs, env, ... }: */ {
    # For some reason having this as a function doesn't work. Don't fully understand why. It's possible we'd need to move this to be imported by the home manager module, home.dano.nix or something.
    # activation = {
    #   createAndroidHome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    #     mkdir -r /home/${env.user}/Android/Sdk
    #   '';
    # };

    sessionVariables = {
      ANDROID_HOME = "/home/${config.env.user}/Android/Sdk";
      CAPACITOR_ANDROID_STUDIO_PATH = "${pkgs.android-studio}/bin/android-studio";
    };
  };
  users.users.${config.env.user} = {
    extraGroups = [
      "adbusers" # Allows access to using `adb`
    ];
  };
}
