#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

scan_paths=(
  "openspec"
  "docs"
  "README.md"
)

patterns=(
  '-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----'
  'sk-[A-Za-z0-9_-]{20,}'
  'gh[pousr]_[A-Za-z0-9_]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{20,}'
  'ya29\.[A-Za-z0-9_-]{20,}'
  'AKIA[0-9A-Z]{16}'
  '(Bearer|Basic)[[:space:]]+[A-Za-z0-9._~+/\-]{12,}=*'
  'https?://[^[:space:]]+:[^[:space:]@]+@'
)

for pattern in "${patterns[@]}"; do
  if rg --pcre2 --hidden --glob '!openspec/changes/archive/**' --glob '!**/.DS_Store' -n -- "$pattern" "${scan_paths[@]}"; then
    echo "Sensitive-looking content found. Review and redact before committing specs." >&2
    exit 1
  fi
done

echo "Spec/doc sanitization scan passed."
