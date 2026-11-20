{ pkgs, config, lib, ... }:
let
  enable = config.my.programs.agents.enable;
  # Pin fetchFromGitHub to a commit rev (not a branch) so sha256 stays stable until
  # you bump rev. To upgrade: set rev to the new commit, then run
  #   nix flake prefetch github:owner/repo/<rev>
  # and copy the printed hash into sha256.
  mattpocockSkills =
    (pkgs.fetchFromGitHub {
      # https://github.com/mattpocock/skills/tree/abeeaf95660ba9e8b7c753eb38f441ca707a8823/skills
      owner = "mattpocock";
      repo = "skills";
      rev = "abeeaf95660ba9e8b7c753eb38f441ca707a8823";
      sha256 = "sha256-fc5+qmchp1IQ/rQP1olWKC1eC4VdYhaB7YYzC3+JBe0=";
    })
    + "/skills";
  # Other skill repos that could be added in the future:
  # https://github.com/deepakness/google-ai-search-optimization - AI search optimization and general SEO
in
{
  config = lib.mkIf enable {
    my.programs.agents = {
      rules = {
        token-efficient =
          (builtins.readFile (
            builtins.fetchurl {
              url = "https://raw.githubusercontent.com/drona23/claude-token-efficient/0d30a6db75af983b8ababf585f28faefdfc87895/CLAUDE.md";
              sha256 = "ZlYSXytPd32ctBSbKsw7AoGqtOjY691N3Nsa6SdOglM=";
            }
          ))
          + ''
            - When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
          '';
        python = ''
          ## Python
          - Adhoc scripts that stay in the standard library: run them with `python3`.
          - Anything that imports a third-party package: `uv run --with <package> script.py` (repeat `--with` for each package). `pip` and `python -m venv` are not available; this Python is externally managed.
        '';
        git = ''
          ## Git
          - Git commits: group into logical changesets. First line under 72 chars, present tense ("Add feature" not "Added feature"). No prefixes (`feat:`, `fix:`, `chore:`, `[ABC-123]`), no ticket numbers, unless project conventions require them.
          - Forbid AI co-authoring in commit messages: never add `Co-authored-by` trailers for agents or tools (Cursor, Claude, etc.), never add "Made with Cursor" or similar attribution trailers, and never use `git commit --trailer` for attribution.
          - Git stash: always prefix the stash message with the current branch name (e.g. `git stash push -m "<branch>: …"`). When listing, applying, popping, or dropping stashes, only touch entries whose message starts with the current branch name — never other agents' stashes.
        '';
        prefer-lists = ''
          ## Output: prefer lists over tables
          When reporting structured results to the user, use lists. Do not use markdown tables.

          Multi-field items: a heading, then one bullet per item, with each field nested:

          # Google Places
          - Tokyo
            - <link to Tokyo>
            - other column value
          - London
            - <link to London>
            - other column value

          Simple rows: one bullet per item, fields inline:

          - Item 1, link to item 1, extra info
          - Item 2, link to item 2, extra info
        '';
      };
      skills = {
        # caveman = mattpocockSkills + "/productivity/caveman/SKILL.md"; # not really using this atm
        handoff = mattpocockSkills + "/productivity/handoff/SKILL.md";
      };
      skill-dirs = {
        # Full dirs so sibling refs resolve (e.g. writing-for-agents → SKILL-MECHANICS.md).
        # write-a-skill was removed upstream; writing-for-agents is the replacement and
        # a dependency of retro.
        grilling = mattpocockSkills + "/productivity/grilling";
        retro = mattpocockSkills + "/engineering/retro";
        writing-for-agents = mattpocockSkills + "/productivity/writing-for-agents";
        "ui-design-brain" = pkgs.fetchFromGitHub {
          # https://github.com/carmahhawwari/ui-design-brain/tree/38f04c5a1dee55d99c686a16643cef4e2ce0f7a2
          owner = "carmahhawwari";
          repo = "ui-design-brain";
          rev = "38f04c5a1dee55d99c686a16643cef4e2ce0f7a2";
          sha256 = "sha256-aOeR/qpkM+gRegRDvJp/SxWVEDLwH5pW0d5FbFkv/AE=";
        };
      };
    };
  };
}
