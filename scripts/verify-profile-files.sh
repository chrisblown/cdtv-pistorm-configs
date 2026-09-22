#!/bin/sh
# Verify that a boot tree contains the exact files fingerprinted by a profile.
set -eu

[ "$#" -eq 2 ] || { echo "Usage: $0 profile.yaml /path/to/boot-tree" >&2; exit 64; }
profile=$1
source_tree=$2
[ -r "$profile" ] && [ -d "$source_tree" ] || { echo "Profile or boot tree is unavailable." >&2; exit 66; }

sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else sha256sum "$1" | awk '{print $1}'; fi
}

failed=0
path=
while IFS= read -r line; do
  case "$line" in
    '  - path: '*) path=$(printf '%s' "${line#'  - path: '}" | sed 's/^"//; s/"$//') ;;
    '    sha256: '*)
      expected=${line#'    sha256: '}
      if [ -z "$path" ] || [ ! -r "$source_tree/$path" ]; then
        echo "MISSING  $path"
        failed=1
      else
        actual=$(sha256 "$source_tree/$path")
        if [ "$actual" = "$expected" ]; then echo "MATCH    $path"; else echo "MISMATCH $path"; failed=1; fi
      fi
      path=
      ;;
  esac
done < "$profile"

exit "$failed"
