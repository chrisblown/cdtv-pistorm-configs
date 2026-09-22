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
done

if find "$root" -type f \( -iname '*.rom' -o -iname '*.img' -o -iname '*.hdf' -o -iname '*.adf' -o -iname '*.card' -o -iname '*.dtbo' \) | grep -q .; then
  echo "Prohibited binary found in registry." >&2
  failed=1
fi

[ "$failed" -eq 0 ] && echo "Registry validation passed."
exit "$failed"
