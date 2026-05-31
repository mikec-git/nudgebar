#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$#" -gt 0 ]]; then
  SEARCH_PATHS=("$@")
else
  SEARCH_PATHS=(
    "$ROOT_DIR/spec"
    "$ROOT_DIR/specs"
    "$ROOT_DIR/.spec"
    "$ROOT_DIR/.specs"
    "$ROOT_DIR/docs/design/specs"
    "$ROOT_DIR/../nudgebar-specs"
  )
fi

SECRET_PATTERN='(BEGIN[[:space:]]+(RSA|OPENSSH|EC|DSA)?[[:space:]]*PRIVATE[[:space:]]+KEY|gh[pousr]_[A-Za-z0-9_]{30,}|xox[baprs]-[A-Za-z0-9-]{20,}|sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{30,}|ya29\.[0-9A-Za-z_-]+|client[_-]?secret[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,}|refresh[_-]?token[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,}|access[_-]?token[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,}|api[_-]?key[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,}|password[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,})'

found=0

for path in "${SEARCH_PATHS[@]}"; do
  [[ -e "$path" ]] || continue

  while IFS= read -r -d '' file; do
    if LC_ALL=C grep -Eiq "$SECRET_PATTERN" "$file"; then
      printf 'Potential secret pattern found in spec file: %s\n' "$file" >&2
      found=1
    fi
  done < <(
    find "$path" -type f \
      \( -name '*.md' -o -name '*.txt' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) \
      -print0
  )
done

if [[ "$found" -ne 0 ]]; then
  printf 'Spec secret scan failed. Redact or remove secrets before sharing or promoting specs.\n' >&2
  exit 1
fi

printf 'Spec secret scan passed.\n'
