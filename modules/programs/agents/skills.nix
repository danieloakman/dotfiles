{ pkgs, config, lib, ... }:
let
  enable = config.my.programs.agents.enable;
  # Pin fetchFromGitHub to a commit rev (not a branch) so sha256 stays stable until
  # you bump rev. To upgrade: set rev to the new commit, then run
  #   nix flake prefetch github:owner/repo/<rev>
  # and copy the printed hash into sha256.
  # TODO: update rev/sha256 and prefetch to fetch newer mattpocock/skills.
  mattpocockSkills =
    (pkgs.fetchFromGitHub {
      # https://github.com/mattpocock/skills/tree/aaf2453fbdfe7a15c07f11d861224f34ab4b53cb/skills
      owner = "mattpocock";
      repo = "skills";
      rev = "aaf2453fbdfe7a15c07f11d861224f34ab4b53cb";
      sha256 = "sha256-+Px3qIMHGKvi0PK2l5H4j/4YRQ448G9kuWX28cgqPCI=";
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
              url = "https://raw.githubusercontent.com/drona23/claude-token-efficient/702e423f98d0d8963d1b76ac74a66a4f2eed67e8/CLAUDE.md";
              sha256 = "oqokm0Bi63OGF2F/+BvNx40zvlQWqBpYxPm3KbYAgCo=";
            }
          ))
          + ''
          - When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
          '';
        git = ''
          ## Git
          - Git commits: group into logical changesets. First line under 72 chars, present tense ("Add feature" not "Added feature"). No prefixes (`feat:`, `fix:`, `chore:`, `[ABC-123]`), no ticket numbers, unless project conventions require them.
          - Forbid AI co-authoring in commit messages: never add `Co-authored-by` trailers for agents or tools (Cursor, Claude, etc.), never add "Made with Cursor" or similar attribution trailers, and never use `git commit --trailer` for attribution.
        '';
      };
      skills = {
        grill-me = mattpocockSkills + "/productivity/grill-me/SKILL.md";
        # caveman = mattpocockSkills + "/productivity/caveman/SKILL.md"; # not really using this atm
        handoff = mattpocockSkills + "/productivity/handoff/SKILL.md";
        write-a-skill = mattpocockSkills + "/productivity/write-a-skill/SKILL.md";
      };
      skillDirs = {
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
