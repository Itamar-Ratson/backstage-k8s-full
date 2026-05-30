#!/usr/bin/env bash
set -euo pipefail

owner="Itamar-Ratson"
lower_owner="$(printf '%s-%s' itamar ratson)"
repo="backstage-k8s-full"
patterns=("${owner}/${repo}" "${lower_owner}/${repo}")
allowlist='^(./)?docs/adr/0004-backstage-rbac.md$'
violations=()

for pattern in "${patterns[@]}"; do
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
      -- "$pattern" . || true
  )
done

if [ "${#violations[@]}" -eq 0 ]; then
  echo "Literal repo slug guard passed"
  exit 0
fi

printf 'Literal repo slug guard failed:\n' >&2
printf '%s\n' "${violations[@]}" >&2
exit 1
