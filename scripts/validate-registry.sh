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
      echo "Profile config must contain exactly one kernel statement: $profile" >&2
      failed=1
    fi
  fi
done

if find "$root" -type f \( -iname '*.rom' -o -iname '*.img' -o -iname '*.hdf' -o -iname '*.adf' -o -iname '*.card' -o -iname '*.dtbo' \) | grep -q .; then
  echo "Prohibited binary found in registry." >&2
  failed=1
fi

[ "$failed" -eq 0 ] && echo "Registry validation passed."
exit "$failed"
