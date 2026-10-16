# Live NixOS installer ISO (vimjoyer / wiki style).
# Boot the USB, mount the target at /mnt, then: install-host akatosh
{ pkgs, lib, modulesPath, dotfiles, ... }:
let
  sshKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCH/B3GF0EynMKOXHDcQLG1NDPQwgKqith6wec7rmMHq7rVANn3iM7p85ZzoeXAWVgYloszX5HFv49nqVmaG93Bzr8R9HBHl7lW3Kee8TpGczy+1wywStXU7ldJ+PjJhrSQvpE9Znyekro4M4Div2bEPML/MRFKq/ZQLB6owF2470dNnP0w+xOIGJlACNTSNDblGcfomUFqZzqOY7/EOUwiJchEAqMmozdOJ3uqH6ev3TgGEdXMsVo8ikPFgz7gnVCMOBbHpW3fyf/EFHkIDhv+SO4NE6qp3oMB1e3qfWFdGRORzCq77kn0f7uZID4xad84JQi2kj4ldfp7oTC5p3Lsk73cPH35S/FjO0JEPoZVPa74NBQJY4QQs9ngwHOqV2USLRLJg5cVsyIp9npBi/4ifKZPo1rkFtE969C/oX4XLrKdn65itjmt24FcW4ojlbMnxqWs/KFbmsGIAD9mcUDPAAA8YIDuBMR29naV/LTC8vIg7/h0/d5CbSb7Kvyc+6k= doakman94@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILEBLbSD9MCQWRVslpMNVI57u2K03AEp1Qvk9UTqo3jv doakman94@gmail.com"
  ];
  steps = ''
    NixOS installer

    Extra files from this stick are mounted at /nixosdata.
    Dotfiles flake: /etc/dotfiles

    1. Partition the target disk and mount its root at /mnt.
       If the host uses EFI, mount that partition at /mnt/boot.
       The layout and UUIDs must match hosts/<name>.nix.
    2. Install a host. This copies the age key from /nixosdata:

         install-host akatosh
         install-host azura
         install-host mara

    3. Reboot and remove the USB stick.
  '';
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    neovim
    (writeShellScriptBin "install-host" ''
      set -euo pipefail
      host="''${1:-}"
      case "$host" in
        akatosh|azura|mara) ;;
        *)
          echo "Usage: install-host akatosh|azura|mara" >&2
          exit 1
          ;;
      esac
      if [[ "$(id -u)" -ne 0 ]]; then
        exec sudo "$0" "$@"
      fi
      if ! mountpoint -q /mnt; then
        echo "Mount the target root filesystem at /mnt first." >&2
        echo "EFI systems also need the EFI partition at /mnt/boot." >&2
        exit 1
      fi
      mkdir -p /nixosdata
      if [[ ! -f /nixosdata/sops/age/keys.txt ]] && findfs LABEL=NIXOSDATA >/dev/null 2>&1; then
        mount -o umask=077 LABEL=NIXOSDATA /nixosdata
      fi
      if [[ -f /nixosdata/sops/age/keys.txt ]]; then
        mkdir -p /mnt/home/dano/.config/sops/age
        cp /nixosdata/sops/age/keys.txt /mnt/home/dano/.config/sops/age/keys.txt
        chmod 600 /mnt/home/dano/.config/sops/age/keys.txt
      else
        echo "No age key at /nixosdata/sops/age/keys.txt; continuing without it." >&2
      fi
      exec nixos-install --flake /etc/dotfiles#"$host"
    '')
  ];

  services.openssh.enable = true;

  # Snapshot of this repo from the ISO build. Live path: /etc/dotfiles
  environment.etc.dotfiles.source = dotfiles;

  environment.etc."installer-steps.txt".text = steps;

  # Printed again when the console shell starts (the live image autologins as nixos).
  environment.interactiveShellInit = ''
    cat /etc/installer-steps.txt
  '';

  services.getty.helpLine = lib.mkForce ''
    The console logs in as nixos. Follow the steps printed in the shell.
    Wi-Fi: nmtui
  '';

  # Same USB stick, partition labeled NIXOSDATA. nofail so a missing label still boots.
  systemd.mounts = [
    {
      what = "/dev/disk/by-label/NIXOSDATA";
      where = "/nixosdata";
      type = "vfat";
      options = "umask=077,nofail,x-systemd.device-timeout=10s";
      wantedBy = [ "local-fs.target" ];
    }
  ];

  users.users.root.openssh.authorizedKeys.keys = sshKeys;
  users.users.nixos.openssh.authorizedKeys.keys = sshKeys;
}
