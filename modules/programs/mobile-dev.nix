# Development stuff for mobile dev:
{ config, env, pkgs, android-nixpkgs, lib, system, ... }:
let
  cfg = config.my.programs.mobile-dev;
  adbGroup = "adbusers";
  # USB ADB ACL: systemd uaccess alone needs a logind seat; agents/SSH often have none.
  usbEnabled = cfg.usb.enable || cfg.enable;
in
{
  options.my.programs.mobile-dev = {
    enable = lib.mkEnableOption "Enable mobile development tools, such as android development tools, android studio, emulator scripts, etc.";
    usb.enable = lib.mkEnableOption ''
      Physical USB ADB access (adbusers + udev MODE). Enough for seatless/agent hosts
      when project flakes supply the Android SDK; implied by mobile-dev.enable on Linux
    '';
    android-version = lib.mkOption {
      type = lib.types.str;
      default = "36";
      description = "The major android version to download the sdk and other tools for.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf usbEnabled (env.selectPlatform {
      darwin = { }; # USB udev is Linux-only; Darwin uses macOS device permissions
      linux =
        let
          androidAdbUnlock = pkgs.writeShellApplication {
            name = "android-adb-unlock";
            runtimeInputs = [ pkgs.android-tools pkgs.gnugrep pkgs.coreutils ];
            text = ''
              set -euo pipefail
              # Usage: android-adb-unlock <pin>
              # Optional: ANDROID_SERIAL=<serial> when multiple devices are attached.

              if [[ $# -lt 1 ]]; then
                echo "usage: android-adb-unlock <pin>" >&2
                exit 1
              fi
              pin="$1"
              if [[ ! "$pin" =~ ^[0-9]+$ ]]; then
                echo "android-adb-unlock: PIN must be digits only" >&2
                exit 1
              fi

              adb_args=()
              if [[ -n "''${ANDROID_SERIAL:-}" ]]; then
                adb_args+=(-s "$ANDROID_SERIAL")
              fi
              adb() { command adb "''${adb_args[@]}" "$@"; }

              adb wait-for-device
              adb shell input keyevent KEYCODE_WAKEUP >/dev/null
              sleep 0.4

              if adb shell dumpsys window 2>/dev/null | grep -q 'isKeyguardShowing=false'; then
                echo "android-adb-unlock: already unlocked"
                exit 0
              fi

              # Reveal PIN pad (works for swipe → PIN on most Samsung/AOSP lockscreens)
              adb shell input swipe 540 2000 540 800 300 >/dev/null
              sleep 0.5

              # Digit keyevents are more reliable on the keyguard than `input text`
              i=0
              while [[ $i -lt ''${#pin} ]]; do
                d="''${pin:$i:1}"
                adb shell input keyevent $((7 + d)) >/dev/null
                i=$((i + 1))
              done
              adb shell input keyevent KEYCODE_ENTER >/dev/null
              sleep 0.6

              if adb shell dumpsys window 2>/dev/null | grep -q 'isKeyguardShowing=false'; then
                echo "android-adb-unlock: unlocked"
                exit 0
              fi
              echo "android-adb-unlock: keyguard still showing (wrong PIN or UI changed)" >&2
              exit 1
            '';
          };
        in
        {
          environment.systemPackages = [
            pkgs.android-tools
            androidAdbUnlock
          ];
          users.groups.${adbGroup} = { };
          users.users.${env.user}.extraGroups = [ adbGroup ];
          # After systemd sets ID_DEBUG_APPLIANCE=android (70-uaccess.rules).
          services.udev.extraRules = ''
            # Android ADB / Fastboot — group access for seatless sessions (agents, SSH)
            ENV{ID_DEBUG_APPLIANCE}=="android", MODE="0660", GROUP="${adbGroup}"
          '';
        };
    }))

    (lib.mkIf cfg.enable (env.selectPlatform {
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

              ${finalSdkPkgs}/bin/emulator -avd "$avd_name" -gpu "$gpu_mode" "$@"
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

              ${finalSdkPkgs}/bin/avdmanager create avd --name "$avd_name" --package "${systemImageStr}" --device "$device_id" --sdcard "2048M" --force
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
          users.users.${env.user}.extraGroups = [ "kvm" ];
        };
    }))
  ];
}
