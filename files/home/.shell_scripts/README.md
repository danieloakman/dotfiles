# Shell Scripts

## Setup

### If not using nixos:

Paste the following into the end of your .zshrc file.

```bash
# Put at the bottom of ".zshrc":
if [ -f "$HOME/repos/personal/dotfiles/files/home/.shell_scripts/.main_shell" ]; then
  source "$HOME/repos/personal/dotfiles/files/home/.shell_scripts/.main_shell"
fi
```

### If using nixos:

Nothing is required.
The above bash if block is added to the end of the user's .zshrc file by the nixos home-manger config.
