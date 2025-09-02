{ env, ... }: {
  # Turns out we need this in home-manager as well. It's not enough to just have it in the system configuration:
  nixpkgs.config.allowUnfree = true;

  home = {
    username = env.user;
    homeDirectory = env.home;
    stateVersion = "25.05";

    file.".gitconfig".text = ''
      [user]
        name = Daniel (Oakman) Brown
        email = 42539848+danieloakman@users.noreply.github.com
        signingkey = 8FB975523F3FEB6113801C04368C0A3C6913D768
      [credential]
        helper = cache --timeout 604800
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
        helper = !/opt/homebrew/bin/gh auth git-credential
      [credential "https://gist.github.com"]
        helper = 
        helper = !/opt/homebrew/bin/gh auth git-credential
    '';
  };

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;
  };

  services = {
    gpg-agent = {
      enable = true;
      defaultCacheTtl = 604800;
      enableSshSupport = true;
      pinentry.program = "/opt/homebrew/bin/pinentry-mac";
    };
  };
}
