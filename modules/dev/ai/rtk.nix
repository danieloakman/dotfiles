# RTK — token-efficient CLI proxy for AI coding agents.
# https://github.com/rtk-ai/rtk
{ env, config, lib, pkgs, ... }:
let
  cfg = config.my.dev.ai.rtk;
  version = "0.37.2";

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
          sha256 = "1iip188bg24bxgcqdvbx8jab9z6mm1pnkan5l5xnhs3acc2pmyrx";
        };
        aarch64-linux = pkgs.fetchurl {
          url = "${base}/rtk-aarch64-unknown-linux-gnu.tar.gz";
          sha256 = "0issqcxf6skj3d8iw4q7qqvw01zilmd4xfq8gj3f21fblv67z38x";
        };
        aarch64-darwin = pkgs.fetchurl {
          url = "${base}/rtk-aarch64-apple-darwin.tar.gz";
          sha256 = "1jkywa4s2n7w83wymn3ljv5rz5gyya2pjgra0djbpvbxhichmqlr";
        };
        x86_64-darwin = pkgs.fetchurl {
          url = "${base}/rtk-x86_64-apple-darwin.tar.gz";
          sha256 = "152drfcpbnh0ngnnn78pnrccqp817ydjdpm2f7v23qc719sfflj0";
        };
      }.${pkgs.stdenv.hostPlatform.system}
        or (throw "my.programs.rtkAi: unsupported system ${pkgs.stdenv.hostPlatform.system}");

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
  options.my.dev.ai.rtk.enable = lib.mkEnableOption ''
    RTK (rtk-ai/rtk): install the release binary and ensure `rtk init -g` has been applied when missing
  '';

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      home.packages = [ rtk ];
      programs.zsh.initContent = lib.mkOrder 1500 ''
        # RTK (my.dev.ai.rtk): install global hooks if not already present
        if command -v rtk >/dev/null 2>&1; then
          rtk_status="$(rtk init --show 2>/dev/null || true)"
          if [[ "$rtk_status" == *"[--]"* ]] || [[ "$rtk_status" == *"not configured"* ]]; then
            if [[ -e "$HOME/.claude/CLAUDE.md" ]] && [[ ! -w "$HOME/.claude/CLAUDE.md" ]]; then
              # Some setups manage ~/.claude/CLAUDE.md as read-only (e.g. Nix home.file), so
              # full `init -g` fails when it tries to inject @RTK.md into that file.
              rtk init -g --hook-only --auto-patch &>/dev/null || true
              rtk init -g --hook-only --agent cursor --auto-patch &>/dev/null || true
            else
              rtk init -g --auto-patch &>/dev/null || true
              rtk init -g --auto-patch --agent cursor &>/dev/null || true
            fi
          fi
        fi
      '';
    };
  };
}
