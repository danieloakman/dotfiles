{ env, pkgs, ... }:
let
  gh = if pkgs.stdenv.isDarwin then "/opt/homebrew/bin/gh" else "/run/current-system/sw/bin/gh";
in
{
  home-manager.users.${env.user} = {
    home.file = {
      ".gitconfig".text = ''
        [user]
          name = Daniel (Oakman) Brown
          email = 42539848+danieloakman@users.noreply.github.com
          signingkey = 8FB975523F3FEB6113801C04368C0A3C6913D768
        [credential]
          helper = cache --timeout 604800
        [includeIf "gitdir/i:~/repos/fsai/"]
          path = ~/.gitconfig-fsai
        [commit]
          gpgsign = true
        [init]
          defaultBranch = main
        [gpg]
          program = gpg
        [pull]
          ff = true
        [core]
          editor = nano
        [http]
          postBuffer = 524288000
        [gpg "ssh"]
          allowedSignersFile = ~/.config/git/allowed_signers
        [credential "https://github.com"]
          helper = 
          helper = !${gh} auth git-credential
        [credential "https://gist.github.com"]
          helper = 
          helper = !${gh} auth git-credential
        [credential "https://future-secure-ai.ghe.com"]
          helper =
          helper = !${gh} auth git-credential
      '';

      # TODO: move signing key to the main .gitconfig file and just sign everything using the ssh key, not gpg
      ".gitconfig-fsai".text = ''
        [user]
          name = Daniel (Oakman) Brown
          email = daniel.brown@futuresecure.ai
          signingkey = ${if pkgs.stdenv.isDarwin then "~/.ssh/id_rsa.pub" else "~/.ssh/fsai.pub"}
        [gpg]
          format = ssh
      '';

      ".config/git/allowed_signers".text = ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCivErxg4ddykeH3M+hk1hK4ZQX4j5kZCuwBP5ZXsb83uybIApwVOnR/+PEwn+0T2HIUXqSTCZH43TCtvKZFJOLeMFUD7ZeCOspFGUtcm7/b9/dHuwrlbFvI6PZt+mrl713YwMrVWy/7QKcjeOHZIWg4DwMM1/XfYy7sArVFV7L+sHa9GRU7dwrzjD8Q8568OhbjE8xv1mmCcGSMZxUxGkTfh4QoCTGrHgdcXuKsx6qxG+Mt17QdSLgGvNv4cAesLCp/t+1k1eeEFPhplqLdZFgYvAdtOeT/anCmLyKRVBkbuF2agdX7QkxCxqHLzaiI76ipjNmdd2cIIodJIl7+cW32AbH01BUJKsApnDemh/9Hd1UFO0JpFMDYu8f0lGdZWO1ubIjrAqgLomXM9yv0ZPAGfTs/fiAYiuTObsnuSs19w0G8sixm5v60MRxe/xIIGXw+TW/SbFJYds5ITJy67Q6mgfNPeyqnAE1AoSNp0chKFEcm/9GuCiC0w7NeIFxlti3SBrwOyAS6QDLXGkRNFMK3dbcawY+E1oLwM7gQPBDmTPuL07bcYZ/oAE+VXKp/HtxPw/Ec0WrU/JFvg7XvIPp1kT5XeBZPfD+jRLtMTs1R7CC3cguhYtO5QwV7veVMcj6qoTgkQw+JAOLkRjWH+QfvpuP66lLTiMlhd4fKycvFQ== daniel.oakman@auxilis.com.au
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILEBLbSD9MCQWRVslpMNVI57u2K03AEp1Qvk9UTqo3jv doakman94@gmail.com
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIINo8NImIdDm7NxYhJLfp3pYNYmUNEUMqZIi3nIeMUir d.oakman@frogco.live
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC0/Va1s0As1075FsaHO32KXQNNTsFWguqY/e7BXMDskGfHlKDih7hQW7mMkbIF5UfmL6M7ORHUQ5fzxLpok3mCZ5k8qticZbYNDyckAGlll7MN+n0HGR639L/q97nS6SkLejUAt+st0/8kU4WRbistfcbCtioVFNHT1XBr2khI7U3iBex/azd4uex0ws8BhjlgtouvK8D30dPPSmPuOfGwoVnDCo85shweQnudePg0YH2RxR/JZvYrqvc2IWRJXEv0W/yTmOHN6dLM3hRhhqvoIww5ZqP/33qh2MBqL++75HtTf0lCXED1C9hG0dAUYZDjwCOFH7Mr84682dCmP1yO4ypTGOZQ6TGG2NTAOimpBjA5SSQKRrN3jBCA1sCoTbSv70uZP9G79XSgZ6vIPcsBhM3zZ97Y3x8LKYbf0UgE0LPJPWn18tbSKto4BGuI0ltAQLG2IUQbKab9OTztXbKeqb1ZLp22j8hO4XKiLrRsI7H+6HwxBtHj9eXa+7BGHGCOS5aZ1qkeQDFMv+Lcim9q7tlgbchV/9XbkXrTs6h5pCQ723AV12eQEhvlNoatd/uvnWpvy6eDr5hnyT3uftKT11z+Um3fztjXkVn5pHu/GLvXD8D22MrQRM0AigD+uYSezQunyG4MjGhJ+xbFS2lF/KHVKH0gOATVGOlv6BZXbQ== daniel.brown@MY797HJWD7
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICsv+O1aOf/u9dD9bJ2piZDKxWKfI/hnZK58h57f7tTo daniel.brown@futuresecure.ai
      '';
    };
  };
}
