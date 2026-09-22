#!/bin/sh
# Read an Emu68 boot tree (mounted partition or backup) and create a ROM-free profile draft.
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 /path/to/EMU68-boot-tree contributor-name [profile-id]" >&2
  exit 64
fi

volume=$1
author=$2
profile_id=${3:-"$(basename "$volume")-$(date +%F)"}
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

case "$volume" in
  /*) ;;
  *) echo "The boot-tree path must be absolute." >&2; exit 64 ;;
esac

if [ ! -d "$volume" ] || [ ! -r "$volume/CONFIG.TXT" ] || [ ! -r "$volume/Boot/CMDLINE.TXT" ]; then
  echo "Expected readable CONFIG.TXT and Boot/CMDLINE.TXT under $volume." >&2
  exit 66
fi

case "$author" in
  *[!A-Za-z0-9._-]* ) echo "Author may contain only letters, numbers, dot, underscore, and hyphen." >&2; exit 64 ;;
esac
case "$profile_id" in
  *[!A-Za-z0-9._-]* ) echo "Profile ID may contain only letters, numbers, dot, underscore, and hyphen." >&2; exit 64 ;;
esac

draft="$root/profiles/drafts/$author-$profile_id"
if [ -e "$draft" ]; then
  echo "Draft already exists: $draft" >&2
  exit 73
fi

sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else sha256sum "$1" | awk '{print $1}'; fi
}

size_bytes() {
  if stat -f '%z' "$1" >/dev/null 2>&1; then stat -f '%z' "$1";
  else stat -c '%s' "$1"; fi
}

yaml_escape() { sed 's/\\/\\\\/g; s/"/\\"/g'; }

mkdir -p "$draft"
cp "$volume/CONFIG.TXT" "$draft/config.txt"
cp "$volume/Boot/CMDLINE.TXT" "$draft/cmdline.txt"

initramfs=$(awk '/^[[:space:]]*initramfs[[:space:]]+/ { sub(/^[[:space:]]*initramfs[[:space:]]+/, ""); print; exit }' "$volume/CONFIG.TXT")
cmdline=$(awk '!/^[[:space:]]*#/ && NF { last=$0 } END { print last }' "$volume/Boot/CMDLINE.TXT")

{
  echo "schema_version: 1"
  printf 'id: %s\n' "$profile_id"
  printf 'author: %s\n' "$author"
  printf 'captured_at: %s\n' "$(date +%F)"
  echo
  echo "hardware:"
  echo "  machine: unknown"
  echo "  pistorm: unknown"
  echo "  raspberry_pi: unknown"
  echo
  echo "boot:"
  echo "  config_snapshot: config.txt"
  echo "  cmdline_snapshot: cmdline.txt"
  printf '  initramfs_raw: "%s"\n' "$(printf '%s' "$initramfs" | yaml_escape)"
  echo "  overlays:"
  awk '/^[[:space:]]*dtoverlay=/ { sub(/^[[:space:]]*dtoverlay=/, ""); print "    - \"" $0 "\"" }' "$volume/CONFIG.TXT"
  printf '  cmdline: "%s"\n' "$(printf '%s' "$cmdline" | yaml_escape)"
  echo
  echo "files:"
  find "$volume/KERNEL" "$volume/ROMS" "$volume/overlays" -type f ! -name '._*' 2>/dev/null | LC_ALL=C sort | while IFS= read -r file; do
    relative=${file#"$volume"/}
    printf '  - path: "%s"\n' "$(printf '%s' "$relative" | yaml_escape)"
    printf '    size_bytes: %s\n' "$(size_bytes "$file")"
    printf '    sha256: %s\n' "$(sha256 "$file")"
  done
  echo
  echo "test:"
  echo "  status: pending"
  echo "  boot_result: untested"
  echo "  cd_access: untested"
  echo "  scsi_card: untested"
  echo "  notes: \"Captured read-only from mounted boot partition.\""
} > "$draft/profile.yaml"

echo "Draft written: $draft"
echo "The source boot tree was read only; no ROM or binary file was copied."
