#!/usr/bin/env bash
# Enforces ADR-0007: derived platform admin identity, no committed
# admin-login literals. The dev overlay is exempt because the upstream
# owner appears as a path component of the bootstrap image's pull
# reference, not as an admin identity. Fork CI rewrites that path on
# first publish (see .github/scripts/bump-image.sh).
set -euo pipefail

forbidden_login="$(printf '%s-%s' itamar ratson)"
allowlist='^(./)?(docs/adr/(0004-backstage-rbac|0007-.*)\.md|deploy/dev/backstage\.yaml)$'
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
