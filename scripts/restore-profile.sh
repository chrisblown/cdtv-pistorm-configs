#!/bin/sh
# Restore a ROM-free profile from locally available files. Verify-only by default.
set -eu

usage() {
  echo "Usage: $0 profile.yaml /path/to/source-tree /path/to/destination-tree [--commit|-commit] [--backup-dir /absolute/path]" >&2
  exit 64
}

[ "$#" -ge 3 ] || usage
profile=$1
source_tree=$2
destination_tree=$3
shift 3
commit=no
backup_root=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --commit|-commit) commit=yes; shift ;;
    --backup-dir) [ "$#" -ge 2 ] || usage; backup_root=$2; shift 2 ;;
    *) usage ;;
  esac
done

case "$source_tree:$destination_tree" in /*:/*) ;; *) echo "Source and destination paths must be absolute." >&2; exit 64 ;; esac
[ -r "$profile" ] || { echo "Profile is unreadable: $profile" >&2; exit 66; }
[ -d "$source_tree" ] || { echo "Source tree is unavailable: $source_tree" >&2; exit 66; }
[ -d "$destination_tree" ] || { echo "Destination tree is unavailable: $destination_tree" >&2; exit 66; }

source_real=$(CDPATH= cd -- "$source_tree" && pwd)
destination_real=$(CDPATH= cd -- "$destination_tree" && pwd)
[ "$source_real" != "$destination_real" ] || { echo "Source and destination must be different trees." >&2; exit 64; }

profile_dir=$(CDPATH= cd -- "$(dirname "$profile")" && pwd)
config_snapshot="$profile_dir/config.txt"
cmdline_snapshot="$profile_dir/cmdline.txt"
[ -r "$config_snapshot" ] && [ -r "$cmdline_snapshot" ] || { echo "Profile must include readable config.txt and cmdline.txt snapshots." >&2; exit 66; }

kernel_count=$(awk '/^[[:space:]]*kernel[[:space:]]*=/ { count++ } END { print count + 0 }' "$config_snapshot")
[ "$kernel_count" -eq 1 ] || { echo "Profile config.txt must contain exactly one kernel= statement; found $kernel_count." >&2; exit 65; }

sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else sha256sum "$1" | awk '{print $1}'; fi
}

size_bytes() {
  if stat -f '%z' "$1" >/dev/null 2>&1; then stat -f '%z' "$1";
  else stat -c '%s' "$1"; fi
}

lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

assert_safe_relative_path() {
  case "$1" in ''|/*|../*|*/../*|*'/..') echo "Unsafe profile path: $1" >&2; exit 65 ;; esac
}

# Find a source asset by SHA-256, not filename. Contributors may name an
# identical ROM or kernel differently while still providing the same bytes.
resolve_source_by_sha() {
  expected_sha=$1
  label=$2
  matches=$( (find "$source_real" -type f ! -name '._*' -print 2>/dev/null || true) | LC_ALL=C sort | while IFS= read -r candidate; do
    if [ "$(sha256 "$candidate")" = "$expected_sha" ]; then printf '%s\n' "$candidate"; fi
  done)
  count=$(printf '%s\n' "$matches" | awk 'NF { count++ } END { print count + 0 }')
  [ "$count" -gt 0 ] || { echo "No source file matches the required SHA-256 for $label." >&2; exit 66; }
  if [ "$count" -gt 1 ]; then
    echo "Multiple source files match $label; using the first deterministic match." >&2
  fi
  printf '%s\n' "$matches" | awk 'NF { print; exit }'
}

destination_path() {
  relative=$1
  direct="$destination_real/$relative"
  if [ -e "$direct" ]; then printf '%s\n' "$direct"; return; fi
  wanted=$(lowercase "$relative")
  matches=$( (find "$destination_real" -type f -print 2>/dev/null || true) | while IFS= read -r candidate; do
    candidate_relative=${candidate#"$destination_real"/}
    if [ "$(lowercase "$candidate_relative")" = "$wanted" ]; then printf '%s\n' "$candidate"; fi
  done)
  count=$(printf '%s\n' "$matches" | awk 'NF { count++ } END { print count + 0 }')
  [ "$count" -le 1 ] || { echo "Ambiguous destination match for $relative." >&2; exit 65; }
  [ "$count" -eq 1 ] && printf '%s\n' "$matches" || printf '%s\n' "$direct"
}

assets=$(awk '
  /^  - path: / { path = $0; sub(/^  - path: /, "", path); sub(/^"/, "", path); sub(/"$/, "", path) }
  /^    sha256: / && path != "" { sha = $0; sub(/^    sha256: /, "", sha); print path "|" sha; path = "" }
' "$profile")
[ -n "$assets" ] || { echo "Profile contains no fingerprinted files." >&2; exit 65; }

verified=0
printf '%s\n' "$assets" | while IFS='|' read -r relative expected_sha; do
  assert_safe_relative_path "$relative"
  source_file=$(resolve_source_by_sha "$expected_sha" "$relative")
  source_relative=${source_file#"$source_real"/}
  printf 'VERIFIED  %s  <-  %s  (%s bytes)\n' "$relative" "$source_relative" "$(size_bytes "$source_file")"
  verified=$((verified + 1))
done

printf '\nProfile assets verified. Planned destination: %s\n' "$destination_real"
printf '%s\n' "$assets" | while IFS='|' read -r relative _; do printf '  replace %s\n' "$relative"; done
printf '  replace CONFIG.TXT\n  replace Boot/CMDLINE.TXT\n'

if [ "$commit" != yes ]; then
  echo "Verify-only mode: no files were changed. Re-run with --commit to restore this profile."
  exit 0
fi

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
if [ -z "$backup_root" ]; then backup_root="$repo_root/backups"; fi
case "$backup_root" in /*) ;; *) echo "Backup directory must be an absolute path." >&2; exit 64 ;; esac
backup_root_real=$(CDPATH= cd -- "$(dirname "$backup_root")" 2>/dev/null && pwd)/$(basename "$backup_root")
case "$backup_root_real" in "$destination_real"|"$destination_real"/*) echo "Backup directory must be outside the destination tree." >&2; exit 64 ;; esac

profile_id=$(awk '/^id: / { print substr($0, 5); exit }' "$profile")
[ -n "$profile_id" ] || profile_id=profile
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$backup_root_real/$timestamp-$profile_id"

printf '\nWARNING: you are about to replace active boot files in:\n  %s\n' "$destination_real"
printf 'A backup of replaced files will be written to:\n  %s\n' "$backup_dir"
printf 'Confirm that the destination is the intended SD-card boot partition and that you have an additional full-card backup. Continue? [Y/N] '
IFS= read -r answer
case "$answer" in Y|y) ;; *) echo "Cancelled. No files were changed."; exit 0 ;; esac

mkdir -p "$backup_dir/originals"
backup_manifest="$backup_dir/manifest.tsv"
printf 'path\tstatus\tsha256\tsize_bytes\n' > "$backup_manifest"

backup_existing() {
  relative=$1
  target=$(destination_path "$relative")
  if [ -e "$target" ]; then
    backup_file="$backup_dir/originals/$relative"
    mkdir -p "$(dirname "$backup_file")"
    cp "$target" "$backup_file"
    printf '%s\tpresent\t%s\t%s\n' "$relative" "$(sha256 "$target")" "$(size_bytes "$target")" >> "$backup_manifest"
  else
    printf '%s\tabsent\t-\t-\n' "$relative" >> "$backup_manifest"
  fi
}

printf '%s\n' "$assets" | while IFS='|' read -r relative _; do backup_existing "$relative"; done
backup_existing CONFIG.TXT
backup_existing Boot/CMDLINE.TXT

restore_asset() {
  relative=$1
  expected_sha=$2
  source_file=$(resolve_source_by_sha "$expected_sha" "$relative")
  target=$(destination_path "$relative")
  mkdir -p "$(dirname "$target")"
  cp "$source_file" "$target"
}

printf '%s\n' "$assets" | while IFS='|' read -r relative expected_sha; do restore_asset "$relative" "$expected_sha"; done
config_target=$(destination_path CONFIG.TXT)
cmdline_target=$(destination_path Boot/CMDLINE.TXT)
mkdir -p "$(dirname "$config_target")" "$(dirname "$cmdline_target")"
cp "$config_snapshot" "$config_target"
cp "$cmdline_snapshot" "$cmdline_target"

printf '%s\n' "$assets" | while IFS='|' read -r relative expected_sha; do
  target=$(destination_path "$relative")
  [ "$(sha256 "$target")" = "$expected_sha" ] || { echo "Post-copy SHA verification failed: $relative" >&2; exit 74; }
done

echo "Restore complete. Backup: $backup_dir"
