#!/usr/bin/env bash
set -euo pipefail

forbidden_login="$(printf '%s-%s' itamar ratson)"
allowlist='^(./)?docs/adr/(0004-backstage-rbac|0007-.*)\.md$'
violations=()

while IFS= read -r match; do
  file="${match%%:*}"
  file="${file#./}"
  if [[ ! "$file" =~ $allowlist ]]; then
    violations+=("$match")
  fi
done < <(
  grep -RInF \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=.terraform \
    --exclude-dir=.techdocs-output \
    -- "$forbidden_login" . || true
)

if [ "${#violations[@]}" -eq 0 ]; then
  echo "Literal admin login guard passed"
  exit 0
fi

printf 'Literal admin login guard failed:\n' >&2
printf '%s\n' "${violations[@]}" >&2
exit 1
