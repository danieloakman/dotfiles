# Pickers (default): space-f (files), space-/ (project search), space-b (buffers).
# https://docs.helix-editor.com/master/pickers.html
{ config, lib, env, ... }:
let
  cfg = config.my.programs.helix;

  # VS Code / Cursor use Cmd on macOS and Ctrl on Linux.
  mod =
    env.selectPlatform {
      darwin = "Cmd";
      linux = "C";
    };

  k = suffix: "${mod}-${suffix}";

  # VS Code / Cursor shortcuts not mapped (no close Helix equivalent):
  #   ${k "d"}  — add selection to next find match / multi-cursor
  #   ${k "h"}  — find and replace panel
  #   ${k "`"}  — toggle integrated terminal
  #   ${k "n"}  — new untitled file
  #   ${k "o"}  — open file dialog (use ${k "p"} file_picker instead)
  #   ${k "S-k"} — delete line (use delete_selection / normal-mode d)
  #
  # Approximate only (mapped, but behavior differs from VS Code):
  #   ${k "b"}  — buffer_picker (VS Code: toggle primary sidebar / explorer)
  #   ${k "l"}  — extend_to_line_bounds (VS Code: select line)
  #   ${k "x"}  — delete_selection (VS Code: cut; does not use system clipboard by default)
  #   ${k "S-d"} — copy_selection_on_next_line (VS Code: duplicate line)

  vscodeKeys = {
    normal = {
      "${k "s"}" = ":w";
      "${k "p"}" = "file_picker";
      "${k "S-p"}" = "command_palette";
      "${k "f"}" = "search";
      "${k "S-f"}" = "global_search";
      "${k "g"}" = "goto_line";
      "${k "/"}" = "toggle_line_comments";
      "${k "b"}" = "buffer_picker";
      "${k "w"}" = "wclose";
      "${k "k"}" = ":buffer-close";
      "${k "tab"}" = ":buffer-next";
      "${k "S-tab"}" = ":buffer-previous";
      "${k "z"}" = "undo";
      "${k "S-z"}" = "redo";
      "${k "c"}" = "yank";
      "${k "v"}" = "paste_after";
      "${k "x"}" = "delete_selection";
      "${k "a"}" = "select_all";
      "${k "l"}" = "extend_to_line_bounds";
      "${k "S-d"}" = "copy_selection_on_next_line";
      "F12" = "goto_definition";
      "A-up" = "move_line_up";
      "A-down" = "move_line_down";
    };
    insert = {
      "${k "s"}" = ":w";
      "${k "f"}" = "search";
      "${k "/"}" = "toggle_line_comments";
      "${k "z"}" = "undo";
      "${k "S-z"}" = "redo";
      "${k "c"}" = "yank";
      "${k "v"}" = "paste_after";
      "${k "x"}" = "delete_selection";
      "${k "a"}" = "select_all";
    };
    select = {
      "${k "/"}" = "toggle_line_comments";
      "${k "c"}" = "yank";
      "${k "v"}" = "paste_after";
      "${k "x"}" = "delete_selection";
      "${k "a"}" = "select_all";
    };
  };
in
{
  options.my.programs.helix = {
    enable = lib.mkEnableOption "Enable the Helix editor with custom configuration.";
    vscodeKeybinds.enable = lib.mkEnableOption ''
      Map common VS Code / Cursor shortcuts in Helix.
      Uses Cmd on Darwin and Ctrl on Linux (see modules/programs/helix.nix).
    '';
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user}.programs.helix = {
      enable = true;

      settings = lib.mkMerge [
        {
          theme = "autumn_night";
          editor = {
            line-number = "relative";
            mouse = true;
            cursor-shape = {
              normal = "block";
              insert = "bar";
              select = "underline";
            };
          };
        }
        (lib.mkIf cfg.vscodeKeybinds.enable {
          keys = vscodeKeys;
        })
      ];
    };
  };
}
