# Development stuff for mobile dev:
{ config, env, pkgs, android-nixpkgs, lib, system, ... }:
let
  cfg = config.my.programs.mobile-dev;
  adbGroup = "adbusers";
  # USB ADB ACL: systemd uaccess alone needs a logind seat; agents/SSH often have none.
  usbEnabled = cfg.usb.enable || cfg.enable;
  androidAdbSkill = ./mobile-dev/android-adb;

  # Shared by android-adb-* wrappers. Escaping is for Nix indented strings.
  adbSetup = ''
    # Optional: ANDROID_SERIAL=<serial> when multiple devices are attached.
    adb_args=()
    if [[ -n "''${ANDROID_SERIAL:-}" ]]; then
      adb_args+=(-s "$ANDROID_SERIAL")
    fi
    adb() { command adb "''${adb_args[@]}" "$@"; }
    adb wait-for-device
  '';
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

              if [[ $# -lt 1 ]]; then
                echo "usage: android-adb-unlock <pin>" >&2
                exit 1
              fi
              pin="$1"
              if [[ ! "$pin" =~ ^[0-9]+$ ]]; then
                echo "android-adb-unlock: PIN must be digits only" >&2
                exit 1
              fi

              ${adbSetup}

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

          androidAdbLock = pkgs.writeShellApplication {
            name = "android-adb-lock";
            runtimeInputs = [ pkgs.android-tools ];
            text = ''
              set -euo pipefail
              # Usage: android-adb-lock

              ${adbSetup}
              adb shell input keyevent KEYCODE_SLEEP >/dev/null
              echo "android-adb-lock: locked"
            '';
          };

          androidAdbInfo = pkgs.writeShellApplication {
            name = "android-adb-info";
            runtimeInputs = [ pkgs.android-tools pkgs.gnugrep pkgs.coreutils pkgs.gawk ];
            text = ''
              set -euo pipefail
              # Usage: android-adb-info

              ${adbSetup}

              serial="$(adb get-serialno 2>/dev/null || true)"
              model="$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
              release="$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || true)"
              sdk="$(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r' || true)"
              battery="$(adb shell dumpsys battery 2>/dev/null | awk -F': ' '/level:/{print $2; exit}' | tr -d '\r' || true)"
              screen_on="$(adb shell dumpsys power 2>/dev/null | awk '/mHoldingDisplaySuspendBlocker=/{print $1; exit}' | tr -d '\r' || true)"
              if [[ "$screen_on" == *true* ]]; then
                screen="on"
              else
                screen="off"
              fi
              if adb shell dumpsys window 2>/dev/null | grep -q 'isKeyguardShowing=false'; then
                keyguard="unlocked"
              else
                keyguard="locked"
              fi
              fg="$(adb shell dumpsys activity activities 2>/dev/null \
                | awk '/mResumedActivity|topResumedActivity/{print; exit}' \
                | tr -d '\r' || true)"
              if [[ -z "$fg" ]]; then
                fg="unknown"
              fi

              echo "serial=$serial"
              echo "model=$model"
              echo "android=$release sdk=$sdk"
              echo "battery=''${battery:-unknown}%"
              echo "screen=$screen"
              echo "keyguard=$keyguard"
              echo "foreground=$fg"
            '';
          };

          androidAdbScreenshot = pkgs.writeShellApplication {
            name = "android-adb-screenshot";
            runtimeInputs = [ pkgs.android-tools pkgs.coreutils ];
            text = ''
              set -euo pipefail
              # Usage: android-adb-screenshot [path]
              # Default: $XDG_RUNTIME_DIR/android-adb/screenshot-YYYYMMDD-HHMMSS.png
              #          (falls back to /tmp/android-adb/)

              ${adbSetup}

              outdir="''${XDG_RUNTIME_DIR:-/tmp}/android-adb"
              mkdir -p "$outdir"
              path="''${1:-$outdir/screenshot-$(date +%Y%m%d-%H%M%S).png}"
              mkdir -p "$(dirname "$path")"
              adb exec-out screencap -p > "$path"
              echo "$path"
            '';
          };

          androidAdbClear = pkgs.writeShellApplication {
            name = "android-adb-clear";
            runtimeInputs = [ pkgs.android-tools ];
            text = ''
              set -euo pipefail
              # Usage: android-adb-clear <package>

              if [[ $# -lt 1 ]]; then
                echo "usage: android-adb-clear <package>" >&2
                exit 1
              fi
              pkg="$1"

              ${adbSetup}
              adb shell pm clear "$pkg" >/dev/null
              echo "android-adb-clear: cleared $pkg"
            '';
          };

          androidAdbLaunch = pkgs.writeShellApplication {
            name = "android-adb-launch";
            runtimeInputs = [ pkgs.android-tools ];
            text = ''
              set -euo pipefail
              # Usage: android-adb-launch <package|component|uri>
              #   package   → launcher activity via monkey
              #   pkg/.Act  → am start -n
              #   https://… → VIEW intent

              if [[ $# -lt 1 ]]; then
                echo "usage: android-adb-launch <package|component|uri>" >&2
                exit 1
              fi
              target="$1"

              ${adbSetup}

              if [[ "$target" == *"://"* ]]; then
                adb shell am start -a android.intent.action.VIEW -d "$target" >/dev/null
                echo "android-adb-launch: opened $target"
              elif [[ "$target" == */* ]]; then
                adb shell am start -n "$target" >/dev/null
                echo "android-adb-launch: started $target"
              else
                adb shell monkey -p "$target" -c android.intent.category.LAUNCHER 1 >/dev/null
                echo "android-adb-launch: launched $target"
              fi
            '';
          };

          androidAdbLog = pkgs.writeShellApplication {
            name = "android-adb-log";
            runtimeInputs = [ pkgs.android-tools pkgs.coreutils ];
            text = ''
              set -euo pipefail
              # Usage: android-adb-log <package> [--follow] [--lines N]
              # Default: dump last 200 lines for the package's PID (or all -d if not running).

              if [[ $# -lt 1 ]]; then
                echo "usage: android-adb-log <package> [--follow] [--lines N]" >&2
                exit 1
              fi
              pkg="$1"
              shift
              follow=0
              lines=200
              while [[ $# -gt 0 ]]; do
                case "$1" in
                  --follow) follow=1; shift ;;
                  --lines)
                    if [[ $# -lt 2 ]]; then
                      echo "android-adb-log: --lines needs a value" >&2
                      exit 1
                    fi
                    lines="$2"
                    shift 2
                    ;;
                  *)
                    echo "usage: android-adb-log <package> [--follow] [--lines N]" >&2
                    exit 1
                    ;;
                esac
              done

              ${adbSetup}

              pid="$(adb shell pidof -s "$pkg" 2>/dev/null | tr -d '\r' || true)"
              if [[ -n "$pid" ]]; then
                if [[ "$follow" -eq 1 ]]; then
                  adb logcat --pid="$pid"
                else
                  adb logcat -d --pid="$pid" -t "$lines"
                fi
              else
                echo "android-adb-log: $pkg not running; dumping unfiltered buffer (-t $lines)" >&2
                if [[ "$follow" -eq 1 ]]; then
                  adb logcat
                else
                  adb logcat -d -t "$lines"
                fi
              fi
            '';
          };

          androidAdbGrant = pkgs.writeShellApplication {
            name = "android-adb-grant";
            runtimeInputs = [ pkgs.android-tools ];
            text = ''
              set -euo pipefail
              # Usage: android-adb-grant <package> <permission...>
              # Short names (CAMERA) expand to android.permission.CAMERA.
              # Pass android.permission.* (or other namespaces) unchanged.

              if [[ $# -lt 2 ]]; then
                echo "usage: android-adb-grant <package> <permission...>" >&2
                exit 1
              fi
              pkg="$1"
              shift

              ${adbSetup}

              for raw in "$@"; do
                if [[ "$raw" == *.* ]]; then
                  perm="$raw"
                else
                  perm="android.permission.$raw"
                fi
                adb shell pm grant "$pkg" "$perm"
                echo "android-adb-grant: $pkg ← $perm"
              done
            '';
          };

          androidAdbPackages = [
            pkgs.android-tools
            androidAdbUnlock
            androidAdbLock
            androidAdbInfo
            androidAdbScreenshot
            androidAdbClear
            androidAdbLaunch
            androidAdbLog
            androidAdbGrant
          ];
        in
        {
          environment.systemPackages = androidAdbPackages;

          my.programs.agents.skill-dirs.android-adb = lib.mkIf config.my.programs.agents.enable androidAdbSkill;

          my.programs.agents.sandbox.extra-allowed-packages = lib.mkIf config.my.programs.agents.enable (
            lib.mkAfter androidAdbPackages
          );

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
