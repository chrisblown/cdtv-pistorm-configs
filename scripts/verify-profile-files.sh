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
resolve_source_by_sha() {
  expected_sha=$1
  matches=$( (find "$source_tree" -type f ! -name '._*' -print 2>/dev/null || true) | LC_ALL=C sort | while IFS= read -r candidate; do
    if [ "$(sha256 "$candidate")" = "$expected_sha" ]; then printf '%s\n' "$candidate"; fi
  done)
  printf '%s\n' "$matches" | awk 'NF { print; exit }'
}

path=
while IFS= read -r line; do
  case "$line" in
    '  - path: '*) path=$(printf '%s' "${line#'  - path: '}" | sed 's/^"//; s/"$//') ;;
    '    sha256: '*)
      expected=${line#'    sha256: '}
      source_file=$(resolve_source_by_sha "$expected")
      if [ -z "$path" ] || [ -z "$source_file" ]; then
        echo "MISSING  $path"
        failed=1
      else
        source_relative=${source_file#"$source_tree"/}
        echo "MATCH    $path <- $source_relative"
      fi
      path=
      ;;
  esac
done < "$profile"

exit "$failed"
