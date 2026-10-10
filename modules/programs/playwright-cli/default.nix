# Playwright CLI for coding agents + shared agent skill.
# https://github.com/microsoft/playwright-cli
{ lib
, pkgs
, config
, env
, ...
}:
let
  cfg = config.my.programs.playwright-cli;
  playwrightCli = pkgs.callPackage ./_package.nix { };

  # Upstream skill tells agents to `npm install -g`; rewrite that section so they
  # use the Nix-provided binary and store browsers.
  # Column-0 body: writeText would otherwise preserve Nix indentation as Python indent.
  patchSkillPy = pkgs.writeText "patch-playwright-cli-skill.py" ''
    from pathlib import Path
    import sys

    path = Path(sys.argv[1])
    text = path.read_text()
    start = text.find("## Installation\n")
    end = text.find("\n## ", start + 1)
    if start == -1 or end == -1:
        raise SystemExit("playwright-cli skill: Installation section not found")
    replacement = """## Installation

    `playwright-cli` is already on PATH (Nix module `my.programs.playwright-cli`).
    Browsers come from nixpkgs `playwright-driver` — do **not** run `npm install -g`,
    `npx playwright`, or `playwright-cli install-browser`.

    ```bash
    playwright-cli --help
    playwright-cli open https://example.com
    ```

    """
    path.write_text(text[:start] + replacement + text[end + 1 :])
  '';

  playwrightCliSkill = pkgs.runCommand "playwright-cli-skill"
    {
      nativeBuildInputs = [ pkgs.python3 ];
    } ''
    mkdir -p $out
    cp -R ${playwrightCli.skill}/. $out/
    chmod -R u+w $out
    python3 ${patchSkillPy} "$out/SKILL.md"
  '';
in
{
  options.my.programs.playwright-cli = {
    enable = lib.mkEnableOption ''
      Install Playwright CLI (`playwright-cli`) with nixpkgs browsers and an agent skill
    '';

    enable-agent-skill = lib.mkEnableOption ''
      Install the playwright-cli skill for AI agents (via my.programs.agents)
    '' // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    my.programs.agents.skill-dirs.playwright-cli = lib.mkIf
      (
        cfg.enable-agent-skill && config.my.programs.agents.enable
      )
      playwrightCliSkill;

    my.programs.agents.sandbox.extra-allowed-packages = lib.mkIf
      (
        cfg.enable-agent-skill && config.my.programs.agents.enable
      )
      (lib.mkAfter [ playwrightCli ]);

    home-manager.users.${env.user}.home.packages = [ playwrightCli ];
  };
}
