#! bash
# Generate the types for AGS, Astal, GDK, etc.

AGS_DIR=$DOTFILES_DIR/modules/hyprland/ags
TMP_AGS_DIR=/tmp/ags
rm -rf $AGS_DIR/node_modules $AGS_DIR/@girs $TMP_AGS_DIR
ags init -d $TMP_AGS_DIR
mv $TMP_AGS_DIR/@girs $TMP_AGS_DIR/node_modules $AGS_DIR/
rm -rf $TMP_AGS_DIR
