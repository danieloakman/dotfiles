{ env, ... }: {
  home-manager.users.${env.user}.programs.skhd = {
    enable = true;
    config = ''
      0x3B + left : aerospace focus left
      0x3B + right : aerospace focus right
      0x3B + up : aerospace focus up
      0x3B + down : aerospace focus down

      0x3B + shift + left : aerospace move left
      0x3B + shift + right : aerospace move right
      0x3B + shift + up : aerospace move up
      0x3B + shift + down : aerospace move down
    '';
  };
}
