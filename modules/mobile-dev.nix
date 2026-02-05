# Development stuff for mobile dev:
{ env, pkgs, ... }:
{
  config = env.selectPlatform
    {
      darwin = {
        homebrew = {
          casks = [
            "android-studio"
            "android-platform-tools"
          ];
        };
        home-manager.users.${env.user}.home = {
          sessionVariables = {
            ANDROID_HOME = "${env.home}/Library/Android/sdk";
            CAPACITOR_ANDROID_STUDIO_PATH = "/Applications/Android Studio.app/Contents/MacOS/studio";
          };
        };
      };
      linux = {
        environment.systemPackages = with pkgs; [
          android-tools
          # androidenv.androidPkgs.all.packages.platforms.v9
          android-studio-tools
          scrcpy # For mirroring the screen of your phone to your computer
        ] ++ (if env.deviceType != "server" then [ android-studio ] else [ ]);
        home-manager.users.${env.user}.home = {
          sessionVariables = {
            ANDROID_HOME = "${env.home}/Android/Sdk";
            CAPACITOR_ANDROID_STUDIO_PATH = "${pkgs.android-studio}/bin/android-studio";
          };
        };
        users.users.${env.user} = {
          extraGroups = [
            "adbusers" # Allows access to using `adb`
            "kvm" # Required for Android emulator
          ];
        };
      };
    };
}
