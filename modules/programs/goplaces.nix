# goplaces — CLI for Google Places API (New) + Routes.
# https://github.com/openclaw/goplaces
#
# Injects GOOGLE_PLACES_API_KEY from sops (Linux) or pass (Darwin).
{ lib
, pkgs
, config
, env
, ...
}:
let
  cfg = config.my.programs.goplaces;
  version = "0.4.11";

  goplaces = pkgs.stdenvNoCC.mkDerivation {
    pname = "goplaces";
    inherit version;

    src =
      let
        base = "https://github.com/openclaw/goplaces/releases/download/v${version}";
      in
      {
        x86_64-linux = pkgs.fetchurl {
          url = "${base}/goplaces_${version}_linux_amd64.tar.gz";
          hash = "sha256-oLajAHaeUyECovZS+imBOibEVgjqQNg2/Zfq2Msl5lo=";
        };
        aarch64-linux = pkgs.fetchurl {
          url = "${base}/goplaces_${version}_linux_arm64.tar.gz";
          hash = "sha256-Rfwk7QDYk+7yGH6/9j4Vk/yyHLgqCTt67s142y4hpac=";
        };
        aarch64-darwin = pkgs.fetchurl {
          url = "${base}/goplaces_${version}_darwin_arm64.tar.gz";
          hash = "sha256-k4eJbIGuxHBlEO/WDdlY+99QVuapaN3eoQrU+XI5QCg=";
        };
        x86_64-darwin = pkgs.fetchurl {
          url = "${base}/goplaces_${version}_darwin_amd64.tar.gz";
          hash = "sha256-WuGUDysXJKNToHFmQQ3v2kLAdqwej4KEyB3t6SleSsU=";
        };
      }.${pkgs.stdenv.hostPlatform.system}
        or (throw "my.programs.goplaces: unsupported system ${pkgs.stdenv.hostPlatform.system}");

    # Upstream archive is a single `goplaces` binary (no directories).
    dontUnpack = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      mkdir -p $out/bin
      tar xzf "$src"
      install -Dm755 goplaces $out/bin/goplaces
    '';

    meta = with lib; {
      description = "CLI for Google Places API (New) and Routes";
      homepage = "https://github.com/openclaw/goplaces";
      license = licenses.mit;
      mainProgram = "goplaces";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    };
  };

  hasApiKeyLinux =
    env.platform == "linux" && builtins.hasAttr "google_places_api_key" (config.sops.secrets or { });

  apiKeyPath =
    if hasApiKeyLinux then config.sops.secrets.google_places_api_key.path else null;

  wrappedGoplaces = pkgs.writeShellScriptBin "goplaces" (
    env.selectPlatform {
      linux =
        if hasApiKeyLinux then
          ''
            export GOOGLE_PLACES_API_KEY="$(< ${apiKeyPath})"
            exec ${lib.getExe goplaces} "$@"
          ''
        else
          ''
            echo "goplaces: google_places_api_key sops secret is not configured on this host" >&2
            exit 1
          '';
      darwin = ''
        export GOOGLE_PLACES_API_KEY="$(pass api_keys/personal/google_places)"
        exec ${lib.getExe goplaces} "$@"
      '';
    }
  );
in
{
  options.my.programs.goplaces.enable = lib.mkEnableOption ''
    Install wrapped `goplaces` (Google Places API CLI) with GOOGLE_PLACES_API_KEY injected
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = env.platform == "darwin" || hasApiKeyLinux;
        message = "my.programs.goplaces.enable on Linux requires the google_places_api_key sops secret.";
      }
    ];

    home-manager.users.${env.user}.home.packages = [ wrappedGoplaces ];
  };
}
