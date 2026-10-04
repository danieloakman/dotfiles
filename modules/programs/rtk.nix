# RTK — token-efficient CLI proxy for AI coding agents.
# https://github.com/rtk-ai/rtk
{ env, config, lib, pkgs, ... }:
let
  cfg = config.my.programs.rtk;

  version = "0.51.0";
  rtk = pkgs.stdenvNoCC.mkDerivation {
    pname = "rtk";
    inherit version;

    src =
      let
        base = "https://github.com/rtk-ai/rtk/releases/download/v${version}";
      in
        {
          x86_64-linux = pkgs.fetchurl {
            url = "${base}/rtk-x86_64-unknown-linux-musl.tar.gz";
            sha256 = "1dafpb6akn5ac4cgn676k1bbr0i7wc3vp7zc1z9r02cgkaqx6a2h";
          };
          aarch64-linux = pkgs.fetchurl {
            url = "${base}/rtk-aarch64-unknown-linux-gnu.tar.gz";
            sha256 = "0chnjg0qglkkv3n3qwc7ixlr7vpps43ra0x7xn0j9d39ksnilvcd";
          };
          aarch64-darwin = pkgs.fetchurl {
            url = "${base}/rtk-aarch64-apple-darwin.tar.gz";
            sha256 = "0nfbww6vmccxxs7qxdimnwm5j1n38764pckfy25sq0pw3avxh5w8";
          };
          x86_64-darwin = pkgs.fetchurl {
            url = "${base}/rtk-x86_64-apple-darwin.tar.gz";
            sha256 = "1hiwpq0abzq2jjdgd0bgw6gcqcc1b9k53p67c21kais17wawhfdx";
          };
        }.${pkgs.stdenv.hostPlatform.system}
          or (throw "my.programs.rtk: unsupported system ${pkgs.stdenv.hostPlatform.system}");

    # Upstream assets are gzip-compressed tar with a single `rtk` file (not a raw ELF). Default Nix unpack
    # rejects "no directories" archives, so extract in installPhase.
    dontUnpack = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      mkdir -p $out/bin
      tar xzf "$src"
      install -Dm755 rtk $out/bin/rtk
    '';

    meta = with lib; {
      description = "CLI proxy that reduces LLM token consumption on common dev commands";
      homepage = "https://github.com/rtk-ai/rtk";
      license = licenses.mit;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    };
  };
in
{
  options.my.programs.rtk.enable = lib.mkEnableOption ''
    RTK (rtk-ai/rtk): install the release binary and remind at shell startup if global init is missing
  '';

  config = lib.mkIf cfg.enable {
    # Pin ahead of nixpkgs so other consumers (dev-pkgs, headroom) share the same binary.
    nixpkgs.overlays = [ (_final: _prev: { inherit rtk; }) ];

    home-manager.users.${env.user} = {
      home.packages = [ rtk ];
      programs = {
        zsh.initContent = lib.mkOrder 1500 ''
          # RTK (my.programs.rtk): remind to configure global hooks if missing
          if command -v rtk >/dev/null 2>&1; then
            rtk_status="$(rtk init --show 2>/dev/null || true)"
            # Hook not configured, remind to configure
            if [[ "$rtk_status" == *"[--] Hook"* ]]; then
              echo 'RTK: global hooks not configured — run: rtk init -g' >&2
            fi
            if [[ "$rtk_status" == *"[--] Cursor hook"* ]]; then
              echo 'RTK: Cursor hook not configured — run: rtk init -g --agent cursor' >&2
            fi
          fi
        '';
      };
    };
  };
}
