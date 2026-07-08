# RTK — token-efficient CLI proxy for AI coding agents.
# https://github.com/rtk-ai/rtk
{ env, config, lib, pkgs, ... }:
let
  cfg = config.my.programs.rtk;

  # version = "0.38.0";
  # rtk = pkgs.stdenvNoCC.mkDerivation {
  #   pname = "rtk";
  #   inherit version;

  #   src =
  #     let
  #       base = "https://github.com/rtk-ai/rtk/releases/download/v${version}";
  #     in
  #       {
  #         x86_64-linux = pkgs.fetchurl {
  #           url = "${base}/rtk-x86_64-unknown-linux-musl.tar.gz";
  #           sha256 = "1iip188bg24bxgcqdvbx8jab9z6mm1pnkan5l5xnhs3acc2pmyrx";
  #         };
  #         aarch64-linux = pkgs.fetchurl {
  #           url = "${base}/rtk-aarch64-unknown-linux-gnu.tar.gz";
  #           sha256 = "0issqcxf6skj3d8iw4q7qqvw01zilmd4xfq8gj3f21fblv67z38x";
  #         };
  #         aarch64-darwin = pkgs.fetchurl {
  #           url = "${base}/rtk-aarch64-apple-darwin.tar.gz";
  #           sha256 = "1jkywa4s2n7w83wymn3ljv5rz5gyya2pjgra0djbpvbxhichmqlr";
  #         };
  #         x86_64-darwin = pkgs.fetchurl {
  #           url = "${base}/rtk-x86_64-apple-darwin.tar.gz";
  #           sha256 = "152drfcpbnh0ngnnn78pnrccqp817ydjdpm2f7v23qc719sfflj0";
  #         };
  #       }.${pkgs.stdenv.hostPlatform.system}
  #         or (throw "my.programs.rtk: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  #   # Upstream assets are gzip-compressed tar with a single `rtk` file (not a raw ELF). Default Nix unpack
  #   # rejects "no directories" archives, so extract in installPhase.
  #   dontUnpack = true;
  #   dontPatchELF = true;
  #   dontStrip = true;

  #   installPhase = ''
  #     mkdir -p $out/bin
  #     tar xzf "$src"
  #     install -Dm755 rtk $out/bin/rtk
  #   '';

  #   meta = with lib; {
  #     description = "CLI proxy that reduces LLM token consumption on common dev commands";
  #     homepage = "https://github.com/rtk-ai/rtk";
  #     license = licenses.mit;
  #     platforms = [
  #       "x86_64-linux"
  #       "aarch64-linux"
  #       "x86_64-darwin"
  #       "aarch64-darwin"
  #     ];
  #     sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  #   };
  # };
in
{
  options.my.programs.rtk.enable = lib.mkEnableOption ''
    RTK (rtk-ai/rtk): install the release binary and remind at shell startup if global init is missing
  '';

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      home.packages = [ pkgs.rtk ];
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
        claude-code = {
          context = ''
            @RTK.md
          '';
          settings.hooks.PreToolUse = [{
            matcher = "Bash";
            hooks = [{
              type = "command";
              command = "rtk hook claude";
            }];
          }];
        };
      };
    };
  };
}
