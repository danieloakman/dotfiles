# Nebula — mission control TUI for coding agents (AgentSystemLabs / Web Dev Cody).
# https://github.com/AgentSystemLabs/nebula
#
# Bump `version` and refresh `assets.*.hash`:
#   for t in x86_64-unknown-linux-musl aarch64-unknown-linux-musl aarch64-apple-darwin x86_64-apple-darwin; do
#     nix store prefetch-file "https://github.com/AgentSystemLabs/nebula/releases/download/vVERSION/nebula-$t.tar.gz"
#   done
{ lib
, pkgs
, config
, env
, ...
}:
let
  cfg = config.my.programs.nebula;
  version = "0.42.0";

  # Nix system → upstream Rust target triple + release asset hash.
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-9Ae9oCxo0DYUf5vHJBfZuMM+f4f6plWb6WmUjM6+/7o=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-9pyXn4izSWmCB/gly2PIdqB5RPkOmrxYolpi0vrv+YM=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-dVq5eSM2BxxZiXz2VLcTVt+GVma4mqCYFpV3+3RBPVk=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-N5v2I/WaRyZt8Ab8EUNe1EDmSDRSvCbBolwEspFZJL4=";
    };
  };

  system = pkgs.stdenv.hostPlatform.system;
  asset =
    assets.${system} or (throw "my.programs.nebula: unsupported system ${system}");

  nebula = pkgs.stdenvNoCC.mkDerivation {
    pname = "nebula-agents";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/AgentSystemLabs/nebula/releases/download/v${version}/nebula-${asset.target}.tar.gz";
      inherit (asset) hash;
    };

    # Upstream archive is a single statically linked `nebula` binary.
    dontUnpack = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      mkdir -p $out/bin
      tar xzf "$src"
      install -Dm755 nebula $out/bin/nebula
    '';

    meta = with lib; {
      description = "Mission control TUI for coding agents (Claude, Codex, Cursor, …)";
      homepage = "https://github.com/AgentSystemLabs/nebula";
      license = licenses.mit;
      mainProgram = "nebula";
      platforms = lib.attrNames assets;
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    };
  };
in
{
  options.my.programs.nebula = {
    enable = lib.mkEnableOption ''
      Nebula (AgentSystemLabs/nebula): install the agent mission-control TUI release binary
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = nebula;
      description = "Nebula package (upstream GitHub release binary).";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user}.home.packages = [ cfg.package ];
  };
}
