#!/usr/bin/env bash
# Write repo/result/iso/*.iso to a USB disk. Prompts for the device and refuses system disks.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

shopt -s nullglob
isos=("$repo"/result/iso/*.iso)
if ((${#isos[@]} != 1)); then
    echo "Expected one ISO at $repo/result/iso/*.iso" >&2
    echo "Build it with: just iso" >&2
    exit 1
fi
iso="${isos[0]}"
key="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
if [[ ! -f "$key" ]]; then
    echo "Age key not found at $key" >&2
    echo "Set SOPS_AGE_KEY_FILE or place the key at ~/.config/sops/age/keys.txt" >&2
    exit 1
fi

# Whole-disk name (sda, nvme0n1) that backs a mounted system path.
disk_for_mount() {
    local source pkname
    source="$(findmnt -n -o SOURCE "$1" 2>/dev/null || true)"
    [[ -n "$source" ]] || return 0
    pkname="$(lsblk -no PKNAME "$source" 2>/dev/null | head -n1 || true)"
    if [[ -n "$pkname" ]]; then
        printf '%s\n' "$pkname"
    else
        basename "$source"
    fi
}

protected="$(
    {
        disk_for_mount /
        disk_for_mount /boot
        disk_for_mount /nix
        disk_for_mount /home
    } | awk 'NF' | sort -u
)"

# One line per whole disk: name, size, USB/internal/refused, model, mounts.
print_disks() {
    local name size tran vendor model kind mounts label mountpoint extra
    while read -r name size tran vendor model; do
        [[ -n "$name" ]] || continue
        case "$name" in
            loop* | zram* | ram* | dm-* | nbd* | sr*) continue ;;
        esac
        if echo "$protected" | grep -qx "$name"; then
            kind="system disk, refused"
        elif [[ "$tran" == "usb" ]]; then
            kind="USB"
        elif [[ "$tran" == "nvme" || "$tran" == "sata" || "$tran" == "ata" ]]; then
            kind="internal"
        else
            kind="${tran:-unknown bus}"
        fi
        mounts=""
        while read -r mountpoint label; do
            [[ -n "$mountpoint" ]] || continue
            extra="$mountpoint"
            [[ -n "$label" ]] && extra="$extra ($label)"
            mounts="${mounts:+$mounts, }$extra"
        done < <(lsblk -ln -o MOUNTPOINT,LABEL "/dev/$name")
        printf '  %-10s %-8s %-24s %s %s\n' "$name" "$size" "$kind" "$vendor" "$model"
        if [[ -n "$mounts" ]]; then
            printf '             mounted: %s\n' "$mounts"
        fi
    done < <(lsblk -dn -o NAME,SIZE,TRAN,VENDOR,MODEL)
}

echo "ISO: $iso"
echo
echo "Disks:"
print_disks
echo
read -rp "Device to overwrite (name from the list, for example sdb): " answer
answer="${answer#/dev/}"
dev="/dev/$answer"

if [[ ! -b "$dev" ]]; then
    echo "Not a block device: $dev" >&2
    exit 1
fi

case "$answer" in
    loop* | zram* | ram* | dm-* | nbd* | sr*)
        echo "Refusing $dev" >&2
        exit 1
        ;;
esac

if echo "$protected" | grep -qx "$answer"; then
    echo "Refusing $dev: it backs a mounted system filesystem" >&2
    exit 1
fi

model="$(lsblk -d -no SIZE,MODEL "$dev" | sed 's/  */ /g')"
echo
echo "This erases everything on $dev ($model)."
echo "The age key will be copied to a new partition labeled NIXOSDATA."
read -rp "Type $answer to continue: " confirm
if [[ "$confirm" != "$answer" ]]; then
    echo "Aborted." >&2
    exit 1
fi

iso_bytes="$(stat -c%s "$iso")"
disk_bytes="$(lsblk -bn -do SIZE "$dev")"
if ((disk_bytes < iso_bytes + 16 * 1024 * 1024)); then
    echo "$dev is too small for the ISO plus a NIXOSDATA partition" >&2
    exit 1
fi

mapfile -t mounts < <(lsblk -ln -o MOUNTPOINT "$dev" | awk 'NF')
if ((${#mounts[@]})); then
    echo "Unmounting ${mounts[*]}"
    sudo umount "${mounts[@]}"
fi

sudo dd if="$iso" of="$dev" bs=4M status=progress conv=fsync
sync

# The ISO is read-only. Extra files go on a FAT partition in the free space after it.
echo "Adding NIXOSDATA partition..."
echo ',,c' | sudo sfdisk --append --wipe never --wipe-partitions never "$dev"
sudo partx -u "$dev" || true
sudo udevadm settle
part="$(lsblk -lnb -o NAME,TYPE,START "$dev" | awk '$2=="part" { print $3, $1 }' | sort -n | tail -n1 | awk '{ print $2 }')"
if [[ -z "$part" || ! -b "/dev/$part" ]]; then
    echo "Could not find the new partition on $dev" >&2
    exit 1
fi
sudo mkfs.vfat -n NIXOSDATA "/dev/$part"
mnt="$(mktemp -d)"
sudo mount -o umask=077 "/dev/$part" "$mnt"
sudo mkdir -p "$mnt/sops/age"
sudo install -m 600 "$key" "$mnt/sops/age/keys.txt"
sudo umount "$mnt"
rmdir "$mnt"
sync
echo "Wrote $iso to $dev"
echo "Age key is on the NIXOSDATA partition at sops/age/keys.txt"
