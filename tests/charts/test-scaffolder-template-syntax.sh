#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

echo "=== Scaffolder template syntax tests ==="

TEMPLATE_ROOT="${TEMPLATE_ROOT:-templates}"

if [ ! -d "$TEMPLATE_ROOT" ]; then
  echo "ERROR: template root does not exist: $TEMPLATE_ROOT" >&2
  exit 1
fi

mapfile -t template_files < <(find "$TEMPLATE_ROOT" -mindepth 2 -maxdepth 2 -type f -name template.yaml | sort)
mapfile -t template_dirs < <(find "$TEMPLATE_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

if [ "${#template_files[@]}" -eq 0 ]; then
  FAIL=$((FAIL + 1))
  echo "FAIL: discovers scaffolder templates"
  echo "  expected at least one template.yaml under $TEMPLATE_ROOT"
else
  PASS=$((PASS + 1))
fi

for template_dir in "${template_dirs[@]}"; do
  slug="$(basename "$template_dir")"
  if [[ "$slug" =~ ^[a-z][a-z0-9-]*$ || "$slug" =~ ^(decommission)-[a-z][a-z0-9-]*$ ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: template slug convention"
    echo "  template: $slug"
    echo "  expected bare noun slug or approved action slug"
  fi
done

while IFS=$'\t' read -r template_file expression; do
  [ -n "$template_file" ] || continue

  if grep -qE '=>|\?\.|\?\?|\.\.\.|`|\basync\b|\bawait\b' <<<"$expression"; then
    FAIL=$((FAIL + 1))
    echo "FAIL: Nunjucks-compatible expression syntax"
    echo "  file: $template_file"
    echo "  expression: $expression"
    echo "  blacklisted syntax: =>, ?., ??, ..., \`, async, await"
  else
    PASS=$((PASS + 1))
  fi

  if grep -qE '\.(flatMap|flat|at)\(' <<<"$expression"; then
    FAIL=$((FAIL + 1))
    echo "FAIL: Nunjucks-compatible array builtins"
    echo "  file: $template_file"
    echo "  expression: $expression"
    echo "  blacklisted builtins: .flatMap(, .flat(, .at("
  else
    PASS=$((PASS + 1))
  fi
done < <(
  perl -0ne '
    while (/\$\{\{(.*?)\}\}/sg) {
      my $expr = $1;
      $expr =~ s/\s+/ /g;
      $expr =~ s/^\s+|\s+$//g;
      print "$ARGV\t$expr\n";
    }
  ' "${template_files[@]}"
)

report_results "Scaffolder template syntax"
