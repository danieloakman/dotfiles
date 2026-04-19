#! bash

AGS_DIR=$DOTFILES_DIR/modules/hyprland.linux/ags
find $AGS_DIR -type f \( -name "*.tsx" -o -name "*.scss" \) | entr -r ags run $AGS_DIR/app.tsx
