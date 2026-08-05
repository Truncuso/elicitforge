#!/usr/bin/env bash
# Offline, deterministic eval harness for the interview engine core.
#
# No network calls, no model dependency, no environment variables: every path is
# resolved relative to this script, so the harness passes from any cwd.
#
#   run.sh                    run every registered suite
#   run.sh --suite <name>     run one registered suite
#
# Exit codes: 0 all cases passed; 1 a case failed, an unknown suite was named,
# or a registered suite discovered zero cases (never a silent empty pass).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CASES_DIR="$SCRIPT_DIR/cases"

# Explicit suite registry. This list is the hard contract downstream work
# packages consume via --suite; adding a suite means adding it here AND
# shipping at least one case under cases/<suite>/.
SUITES=(contract purity presets)

usage() {
  printf 'usage: run.sh [--suite %s]\n' "$(IFS='|'; echo "${SUITES[*]}")" >&2
}

selected=()
while [ $# -gt 0 ]; do
  case "$1" in
    --suite)
      [ $# -ge 2 ] || { echo "error: --suite requires a suite name" >&2; usage; exit 1; }
      selected+=("$2")
      shift 2
      ;;
    --suite=*)
      selected+=("${1#--suite=}")
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

is_registered() {
  local candidate="$1" s
  for s in "${SUITES[@]}"; do
    [ "$s" = "$candidate" ] && return 0
  done
  return 1
}

if [ ${#selected[@]} -eq 0 ]; then
  selected=("${SUITES[@]}")
else
  for s in "${selected[@]}"; do
    if ! is_registered "$s"; then
      echo "error: unknown suite '$s' (registered: ${SUITES[*]})" >&2
      exit 1
    fi
  done
fi

failed=0
total_cases=0

for suite in "${selected[@]}"; do
  cases=()
  while IFS= read -r c; do
    [ -n "$c" ] && cases+=("$c")
  done < <(find "$CASES_DIR/$suite" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)

  printf 'suite=%s cases=%d\n' "$suite" "${#cases[@]}"

  if [ ${#cases[@]} -eq 0 ]; then
    echo "error: registered suite '$suite' discovered zero cases in $CASES_DIR/$suite — a registered suite with no cases is a failure, not a pass" >&2
    failed=$((failed + 1))
    continue
  fi

  for case_file in "${cases[@]}"; do
    total_cases=$((total_cases + 1))
    name="$(basename "$case_file" .sh)"
    if bash "$case_file" "$CORE_DIR"; then
      printf '  PASS %s/%s\n' "$suite" "$name"
    else
      printf '  FAIL %s/%s\n' "$suite" "$name" >&2
      failed=$((failed + 1))
    fi
  done
done

if [ "$failed" -ne 0 ]; then
  printf 'FAILED: %d failure(s) across %d case(s)\n' "$failed" "$total_cases" >&2
  exit 1
fi

printf 'OK: %d case(s) passed\n' "$total_cases"
