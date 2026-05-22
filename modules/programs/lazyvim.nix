# LazyVim (https://www.lazyvim.org/) via lazyvim-nix — Linux and Darwin.
# https://github.com/pfassina/lazyvim-nix
{ config, lib, env, inputs, ... }:
let
  cfg = config.my.programs.lazyvim;

  # VS Code / Cursor use Cmd on macOS and Ctrl on Linux.
  mod =
    env.selectPlatform {
      darwin = "D";
      linux = "C";
    };

  key = suffix: "<${mod}-${suffix}>";

  # VS Code / Cursor shortcuts not mapped (no close LazyVim equivalent):
  #   ${key "d"}  — add selection to next find match / multi-cursor
  #   ${key "h"}  — find and replace panel (use :%s/ or Telescope replace)
  #   ${key "`"}  — toggle integrated terminal (LazyVim: <leader>ft or extras.terminal)
  #
  # Approximate only (mapped, but behavior differs from VS Code):
  #   ${key "b"}  — Neotree toggle (VS Code: primary sidebar / explorer)
  #   ${key "l"}  — visual line select (VS Code: select line; conflicts with terminal clear-screen on some terms)
  #   ${key "x"}  — delete (VS Code: cut; use "+d in visual for system clipboard cut)
  #   ${key "S-d"} — duplicate line below

  vscodeKeymaps = ''
    do
      local opts = { desc = "VS Code style" }
      local function map(modes, lhs, rhs, desc)
        vim.keymap.set(modes, lhs, rhs, vim.tbl_extend("force", opts, { desc = desc or opts.desc }))
      end

      map({ "i", "n", "v" }, "${key "s"}", "<cmd>write<cr>", "Save")
      map("n", "${key "p"}", "<cmd>Telescope find_files<cr>", "Quick open")
      map("n", "${key "S-p"}", "<cmd>Telescope commands<cr>", "Command palette")
      map("n", "${key "f"}", "<cmd>Telescope current_buffer_fuzzy_find<cr>", "Find in file")
      map("n", "${key "S-f"}", "<cmd>Telescope live_grep<cr>", "Search in files")
      map("n", "${key "g"}", "<cmd>Telescope lines<cr>", "Go to line")
      map({ "n", "i", "v" }, "${key "/"}", function()
        require("Comment.api").toggle.linewise.current()
      end, "Toggle comment")
      map("n", "${key "b"}", "<cmd>Neotree toggle<cr>", "Toggle file tree")
      map("n", "${key "w"}", "<cmd>close<cr>", "Close window")
      map("n", "${key "k"}", "<cmd>bd<cr>", "Close buffer")
      map("n", "${key "Tab"}", "<cmd>bnext<cr>", "Next buffer")
      map("n", "${key "S-Tab"}", "<cmd>bprevious<cr>", "Previous buffer")
      map({ "i", "n" }, "${key "z"}", "<cmd>undo<cr>", "Undo")
      map({ "i", "n" }, "${key "S-z"}", "<cmd>redo<cr>", "Redo")
      map({ "n", "v" }, "${key "c"}", '"+y', "Copy")
      map("n", "${key "v"}", '"+p', "Paste")
      map("i", "${key "v"}", '<C-r>+', "Paste")
      map({ "n", "v" }, "${key "x"}", '"+d', "Cut")
      map("n", "${key "a"}", "ggVG", "Select all")
      map("n", "${key "l"}", "V", "Select line")
      map("n", "${key "S-d"}", "<cmd>call append(line('.'), getline('.'))<cr>", "Duplicate line")
      map("n", "F12", "<cmd>lua vim.lsp.buf.definition()<cr>", "Go to definition")
      map("n", "A-j", "<cmd>m .+1<cr>==", "Move line down")
      map("n", "A-k", "<cmd>m .-2<cr>==", "Move line up")
    end
  '';
in
{
  options.my.programs.lazyvim = {
    enable = lib.mkEnableOption "Enable Neovim with the LazyVim distribution.";
    enableVSCodeKeybinds = lib.mkEnableOption ''
      Map common VS Code / Cursor shortcuts on top of LazyVim defaults.
      Uses Cmd on Darwin and Ctrl on Linux (see modules/programs/lazyvim.nix).
    '';
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.my.programs.helix.enable;
        message = "my.programs.lazyvim and my.programs.helix cannot both be enabled.";
      }
    ];

    home-manager.users.${env.user} = {
      imports = [ inputs.lazyvim.homeManagerModules.default ];

      programs = {
        lazyvim = {
          enable = true;

          extras.lang.nix.enable = true;

          config = {
            options = ''
              vim.opt.relativenumber = true
              vim.opt.wrap = true
            '';
            keymaps = lib.mkIf cfg.enableVSCodeKeybinds vscodeKeymaps;
          };
        };
        zsh = {
          shellAliases = {
            "vim" = "nvim";
            "editor" = "nvim";
            "lvim" = "nvim";
          };
          initContent = ''
            # Set the default editor to lazyvim
            export EDITOR="nvim"
          '';
        };
      };
    };
  };
}
