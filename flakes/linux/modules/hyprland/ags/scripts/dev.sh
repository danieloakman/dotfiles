#! bash

AGS_DIR=$DOTFILES_DIR/flakes/linux/modules/hyprland/ags
find $AGS_DIR -type f \( -name "*.tsx" -o -name "*.scss" \) | entr -r ags run $AGS_DIR/app.tsx
