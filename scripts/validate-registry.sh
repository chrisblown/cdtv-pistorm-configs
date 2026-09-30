#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
failed=0

for profile in "$root"/profiles/*/*/profile.yaml "$root"/profiles/drafts/*/profile.yaml; do
  [ -f "$profile" ] || continue
  if ! grep -Eq '^schema_version: 1$' "$profile"; then
    echo "Invalid or missing schema version: $profile" >&2
    failed=1
  fi
  if ! grep -Eq '^    sha256: [0-9a-f]{64}$' "$profile"; then
    echo "Missing or malformed file fingerprint: $profile" >&2
    failed=1
  fi
  config_snapshot="$(dirname "$profile")/config.txt"
  if [ ! -r "$config_snapshot" ]; then
    echo "Missing config snapshot: $profile" >&2
    failed=1
  else
    kernel_count=$(awk '/^[[:space:]]*kernel[[:space:]]*=/ { count++ } END { print count + 0 }' "$config_snapshot")
    if [ "$kernel_count" -ne 1 ]; then
      pistorm_type=$(awk '/^  pistorm_type: / { print substr($0, 17); exit }' "$profile")
      case "$pistorm_type" in
        classic) selected_section='[gpio17=0]' ;;
        pistorm16) selected_section='[gpio24=1]' ;;
        pistorm32lite) selected_section='[gpio24=0]' ;;
        pistorm32lite-stealth) selected_section='[gpio4=0]' ;;
        *) selected_section= ;;
      esac
      selected_kernel_count=$(awk -v selected_section="$selected_section" '
        BEGIN { scope = "global" }
        {
          line = $0; sub(/\r$/, "", line)
          section = line; sub(/^[[:space:]]*/, "", section); sub(/[[:space:]]*$/, "", section)
          if (section ~ /^\[/) {
            if (section == "[all]") scope = "global"
            else if (section == selected_section) scope = "selected"
            else scope = "other"
            next
          }
          if ((scope == "global" || scope == "selected") && line ~ /^[[:space:]]*kernel[[:space:]]*=/) count++
        }
        END { print count + 0 }
      ' "$config_snapshot")
      if [ -z "$selected_section" ] || [ "$selected_kernel_count" -ne 1 ]; then
        echo "Profile config must contain exactly one kernel statement, or one kernel for its PiStorm type: $profile" >&2
        failed=1
      fi
    fi
  fi
done

if find "$root" -type f \( -iname '*.rom' -o -iname '*.img' -o -iname '*.hdf' -o -iname '*.adf' -o -iname '*.card' -o -iname '*.dtbo' \) | grep -q .; then
  echo "Prohibited binary found in registry." >&2
  failed=1
fi

[ "$failed" -eq 0 ] && echo "Registry validation passed."
exit "$failed"
