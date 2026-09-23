#!/bin/sh
# Read an Emu68 boot tree (mounted partition or backup) and create a ROM-free profile draft.
set -eu

usage() {
  echo "Usage: $0 /path/to/EMU68-boot-tree contributor-name profile-id [--machine CDTV|A570|A690] [--initramfs comma,separated,paths]" >&2
  exit 64
}

[ "$#" -ge 3 ] || usage
source_tree=$1
author=$2
profile_id=$3
shift 3
selected_kernel=
selected_initramfs=
machine=CDTV

while [ "$#" -gt 0 ]; do
  case "$1" in
    --initramfs) [ "$#" -ge 2 ] || usage; selected_initramfs=$2; shift 2 ;;
    --machine) [ "$#" -ge 2 ] || usage; machine=$2; shift 2 ;;
    *) usage ;;
  esac
done

case "$source_tree" in /*) ;; *) echo "The boot-tree path must be absolute." >&2; exit 64 ;; esac
case "$author" in *[!A-Za-z0-9._-]* ) echo "Invalid author." >&2; exit 64 ;; esac
case "$profile_id" in *[!A-Za-z0-9._-]* ) echo "Invalid profile ID." >&2; exit 64 ;; esac
case "$machine" in CDTV|A570|A690) ;; *) echo "Machine must be CDTV, A570, or A690." >&2; exit 64 ;; esac

config="$source_tree/CONFIG.TXT"
cmdline_file="$source_tree/Boot/CMDLINE.TXT"
if [ ! -d "$source_tree" ] || [ ! -r "$config" ] || [ ! -r "$cmdline_file" ]; then
  echo "Expected readable CONFIG.TXT and Boot/CMDLINE.TXT under $source_tree." >&2
  exit 66
fi

kernel_count=$(awk '/^[[:space:]]*kernel[[:space:]]*=/ { count++ } END { print count + 0 }' "$config")
if [ "$kernel_count" -ne 1 ]; then
  echo "CONFIG.TXT must contain exactly one active kernel= statement; found $kernel_count. GPIO/multi-kernel configurations are not accepted." >&2
  exit 65
fi
selected_kernel=$(awk '/^[[:space:]]*kernel[[:space:]]*=/ { sub(/^[[:space:]]*kernel[[:space:]]*=[[:space:]]*/, ""); print; exit }' "$config")

if [ -z "$selected_initramfs" ]; then
  selected_initramfs=$(awk '
    /^\[/ { conditional = 1 }
    conditional == 0 && /^[[:space:]]*initramfs[[:space:]]+/ {
      sub(/^[[:space:]]*initramfs[[:space:]]+/, ""); print; exit
    }
  ' "$config")
fi

if [ -z "$selected_initramfs" ]; then
  echo "No unconditional initramfs found; supply --initramfs explicitly." >&2
  exit 65
fi

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
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
require_asset() {
  relative=$1
  if [ ! -r "$source_tree/$relative" ]; then
    echo "Selected asset is missing or unreadable: $relative" >&2
    exit 66
  fi
}
emit_asset() {
  relative=$1
  role=$2
  file="$source_tree/$relative"
  printf '  - path: "%s"\n' "$(printf '%s' "$relative" | yaml_escape)"
  printf '    role: %s\n' "$role"
  printf '    size_bytes: %s\n' "$(size_bytes "$file")"
  printf '    sha256: %s\n' "$(sha256 "$file")"
}

require_asset "$selected_kernel"
asset_list="$selected_kernel|kernel"

old_ifs=$IFS
IFS=,
set -- $selected_initramfs
IFS=$old_ifs
index=0
for asset in "$@"; do
  [ -n "$asset" ] || continue
  require_asset "$asset"
  index=$((index + 1))
  asset_list="$asset_list\n$asset|initramfs_$index"
done

overlays=$(awk '/^[[:space:]]*dtoverlay=/ { sub(/^[[:space:]]*dtoverlay=/, ""); print }' "$config")
printf '%s\n' "$overlays" | while IFS= read -r overlay; do
  [ -n "$overlay" ] || continue
  name=${overlay%%,*}
  require_asset "overlays/$name.dtbo"
done

mkdir -p "$draft"
cp "$config" "$draft/config.txt"
cp "$cmdline_file" "$draft/cmdline.txt"
cmdline=$(awk '!/^[[:space:]]*#/ && NF { last=$0 } END { print last }' "$cmdline_file")

{
  echo "schema_version: 1"
  printf 'id: %s\n' "$profile_id"
  printf 'author: %s\n' "$author"
  printf 'captured_at: %s\n' "$(date +%F)"
  echo
  echo "hardware:"
  printf '  machine: %s\n' "$machine"
  echo
  echo "versions:"
  echo '  emu68: ""'
  echo '  caffeine_os: ""'
  echo
  echo "boot:"
  echo "  config_snapshot: config.txt"
  echo "  cmdline_snapshot: cmdline.txt"
  printf '  selected_kernel: "%s"\n' "$(printf '%s' "$selected_kernel" | yaml_escape)"
  printf '  initramfs_raw: "%s"\n' "$(printf '%s' "$selected_initramfs" | yaml_escape)"
  echo "  overlays:"
  printf '%s\n' "$overlays" | while IFS= read -r overlay; do [ -n "$overlay" ] && printf '    - "%s"\n' "$(printf '%s' "$overlay" | yaml_escape)"; done
  printf '  cmdline: "%s"\n' "$(printf '%s' "$cmdline" | yaml_escape)"
  echo
  echo "files:"
  printf '%b\n' "$asset_list" | while IFS='|' read -r relative role; do emit_asset "$relative" "$role"; done
  printf '%s\n' "$overlays" | while IFS= read -r overlay; do
    [ -n "$overlay" ] || continue
    name=${overlay%%,*}
    emit_asset "overlays/$name.dtbo" overlay
  done
  echo
  echo "test:"
  echo "  status: pending"
  echo "  boot_result: untested"
  echo "  caffeine_os_boots: untested"
  echo "  cd_access: untested"
  echo "  audio_cd: untested"
  echo "  cd_plus_g: untested"
  echo "  scsi_card: untested"
  echo "  notes: \"Captured read-only from a boot tree with a single active kernel statement.\""
} > "$draft/profile.yaml"

chmod 644 "$draft/config.txt" "$draft/cmdline.txt" "$draft/profile.yaml"
echo "Draft written: $draft"
echo "Only the selected kernel, initramfs assets, and referenced overlays were fingerprinted."
