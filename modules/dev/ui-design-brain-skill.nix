{ env, pkgs, ... }:
{
  home-manager.users.${env.user} = {
    home.file.".agents/skills/ui-design-brain".source = pkgs.fetchFromGitHub {
      owner = "carmahhawwari";
      repo = "ui-design-brain";
      rev = "main";
      sha256 = "sha256-aOeR/qpkM+gRegRDvJp/SxWVEDLwH5pW0d5FbFkv/AE=";
    };
  };
}
