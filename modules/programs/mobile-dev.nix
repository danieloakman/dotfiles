# Development stuff for mobile dev:
{ config, env, pkgs, android-nixpkgs, lib, system, ... }:
let
  cfg = config.my.programs.mobile-dev;
in
{
  options.my.programs.mobile-dev = {
    enable = lib.mkEnableOption "Enable mobile development tools, such as android development tools, android studio, emulator scripts, etc.";
    android-version = lib.mkOption {
      type = lib.types.str;
      default = "36";
      description = "The major android version to download the sdk and other tools for.";
    };
  };

  config = lib.mkIf cfg.enable (env.selectPlatform {
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
    linux =
      let
        majorVersion = cfg.android-version;
        systemImagePkg = "system-images-android-${majorVersion}-google-apis-playstore-x86-64";
        systemImageStr = "system-images;android-${majorVersion};google_apis_playstore;x86_64";
        finalSdkPkgs = android-nixpkgs.sdk.${system}
          (sdkPkgs: with sdkPkgs;
          [
            # Run `nix flake show github:tadfisher/android-nixpkgs` to see all available sdk packages
            sdkPkgs."build-tools-${majorVersion}-0-0"
            sdkPkgs."platforms-android-${majorVersion}"
            sdkPkgs."sources-android-${majorVersion}"
            sdkPkgs.${systemImagePkg}
            cmdline-tools-latest
            platform-tools
            emulator
            ndk-29-0-14206865
            cmake-4-1-2
          ]);
        sdkPath = ".android";
      in
      {
        nixpkgs.config.android_sdk.accept_license = true;
        environment.systemPackages = with pkgs; [
          scrcpy # For mirroring the screen of your phone to your computer
          finalSdkPkgs
          (writeShellScriptBin "android-emulator-list" ''
            ${finalSdkPkgs}/bin/avdmanager list avd
          '')
          (writeShellScriptBin "android-emulator-start" ''
            set -euo pipefail

            if [[ $# -lt 1 ]]; then
              echo "usage: android-emulator-start <avd-name> [extra-emulator-args...]" >&2
              exit 1
            fi

            avd_name="$1"
            shift

            # Prefer host acceleration when an NVIDIA GPU is available.
            gpu_mode="auto"
            if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
              gpu_mode="host"
            fi

            ${android.finalSdkPkgs}/bin/emulator -avd "$avd_name" -gpu "$gpu_mode" "$@"
          '')
          (writeShellScriptBin "android-emulator-shutdown" ''
            ${finalSdkPkgs}/bin/emulator -avd $1 -shutdown
          '')
          (writeShellScriptBin "android-emulator-create" ''
            set -euo pipefail

            if [[ $# -lt 2 ]]; then
              echo "usage: android-emulator-create <avd-name> <device-id>" >&2
              exit 1
            fi

            avd_name="$1"
            device_id="$2"

            ${android.finalSdkPkgs}/bin/avdmanager create avd --name "$avd_name" --package "${systemImageStr}" --device "$device_id" --sdcard "2048M" --force
          '')
          (writeShellScriptBin "android-emulator-delete" ''
            ${finalSdkPkgs}/bin/avdmanager delete avd --name $1
          '')
        ];
        home-manager.users.${env.user} = {
          home = {
            sessionVariables = {
              ANDROID_HOME = "${env.home}/${sdkPath}/sdk";
              ANDROID_SDK_ROOT = "${env.home}/${sdkPath}/sdk";
              ANDROID_AVD_ROOT = "${env.home}/${sdkPath}/avd";
              CAPACITOR_ANDROID_STUDIO_PATH = "${lib.getExe pkgs.android-studio}";
            };
            file."${sdkPath}/sdk".source = "${finalSdkPkgs}/share/android-sdk";
          };
        };
        users.users.${env.user} = {
          # These groups might not be required anymore, but leaving them here anyway:
          extraGroups = [
            "adbusers" # Allows access to using `adb`
            "kvm" # Required for Android emulator
          ];
        };
      };
  });
}
