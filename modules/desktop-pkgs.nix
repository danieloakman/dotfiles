# This module is for adding general desktop, system level packages. Stuff that has a GUI:
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # thunderbird
    tailscale
    vscode
    firefox
    google-drive-ocamlfuse
    guake
    # Was trying this out for a week or two. I think guake is just overall a better choice. `pass` autocomplete no longer worked for one. And making the terminal a paid subscription gave me the ick.
    # warp-terminal
    google-chrome
    home-manager
    discord
    zoom-us
    slack
    spotify
    vlc # For video playback
    gimp
    obsidian
    # valent # Was trying this out for tethering with mobile. But couldn't find my phone through bluetooth
    # dropbox # Was trying this out for syncing with mobile. But offline sync on mobile is only available for paid users.
    # ventoy # For creating bootable USBs. It's really cool, just drag and drop ISOs onto the USB and you can select which one to boot from
    # foot # Maybe can use this for quick to load terminal that's a replacement for dmenu in gnome wayland
    # testdisk # For recovering lost partitions and files. Used this for recovering jpg files on an sd card once.
  ];
}
