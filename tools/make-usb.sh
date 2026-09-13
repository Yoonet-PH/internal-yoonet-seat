#!/usr/bin/env bash
# Build a bootable Ubuntu 24.04 LTS Desktop USB stick on a Mac.
# Usage: ./tools/make-usb.sh            (downloads the ISO, verifies it, then asks which disk to write)
set -euo pipefail
ISO_URL=https://releases.ubuntu.com/24.04/ubuntu-24.04.3-desktop-amd64.iso
SUMS_URL=https://releases.ubuntu.com/24.04/SHA256SUMS
DL="$HOME/Downloads"; ISO="$DL/$(basename "$ISO_URL")"
echo "==> Ubuntu 24.04 LTS Desktop ISO"
[ -s "$ISO" ] || curl -L --progress-bar -o "$ISO" "$ISO_URL"
curl -fsSL "$SUMS_URL" | grep "$(basename "$ISO")" > "$DL/ubuntu.sha256"
( cd "$DL" && shasum -a 256 -c ubuntu.sha256 ) && echo "    checksum ok"
echo; echo "==> Plug in the USB stick (8GB or larger; everything on it will be erased), then pick it below:"
diskutil list external physical
read -rp "Disk to write (e.g. disk4): " D
diskutil info "/dev/$D" | grep -E "Device Node|Media Name|Disk Size"
read -rp "Type ERASE to write the installer to /dev/$D: " C; [ "$C" = ERASE ] || { echo "cancelled"; exit 1; }
diskutil unmountDisk "/dev/$D"
echo "==> Writing (a few minutes)..."
sudo dd if="$ISO" of="/dev/r$D" bs=4m status=progress
sync; diskutil eject "/dev/$D" || true
echo "==> Done. The stick is ready. On Windows, use Rufus (rufus.ie) with the same ISO instead."
