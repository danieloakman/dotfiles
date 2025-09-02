{ env, lib, ... }: {
  home-manager.users.${env.user} = {
    programs = {
      kitty = {
        enable = true;
        keybindings = {
          "ctrl+c" = "copy_or_interrupt";
          "shift+alt+=" = "launch --location=vsplit";
          "shift+alt+-" = "launch --location=hsplit";
        };
        settings = {
          enabled_layouts = "splits";
          background_opacity = lib.mkForce 0.5; # between 0.0 and 1.0
          background_blur = lib.mkForce 1; # Set to a positive value to enable background blur
        };
      };
    };
  };
}
