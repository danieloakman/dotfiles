{ env, lib, config, ... }:
let
  cfg = config.my.programs.kitty;
in
{
  options.my.programs.kitty.enable = lib.mkEnableOption "Enable the Kitty terminal emulator";

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
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
    (lib.mkIf config.my.desktop.hyprland.enable {
      home-manager.users.${env.user} = { lib, ... }:
        let
          hl = import ../hyprland.linux/_lua-lib.nix { inherit lib; };
        in
        {
          wayland.windowManager.hyprland = {
            settings = {
              term = hl.var "kitty";

              on = [
                # Start a terminal in a special workspace.
                {
                  _args = [
                    "hyprland.start"
                    (lib.generators.mkLuaInline ''
                      function()
                        hl.exec_cmd(term, { workspace = "special silent" })
                      end
                    '')
                  ];
                }
              ];

              bind = [
                (hl.bind (hl.key "return") (lib.generators.mkLuaInline "hl.dsp.exec_cmd(term)"))
                (hl.bind (hl.key "grave") (hl.toggleSpecial "special"))
              ];

              animation = [
                {
                  leaf = "specialWorkspace";
                  enabled = true;
                  speed = 4;
                  bezier = "default";
                  style = "slidevert";
                }
              ];

              config = {
                input = {
                  # Allow clicking around the terminal in its special workspace.
                  special_fallthrough = true;
                };
              };
            };
          };
        };
    })
  ]);
}
