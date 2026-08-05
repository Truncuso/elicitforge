#!/usr/bin/env bash
# Offline, deterministic eval harness for the claude-code adapter.
#
# Mirrors core/evals/run.sh's contract: no network, no model, every path
# resolved relative to this script so the harness passes from any cwd.
#
# Adapter cases are NOT runnable from core/evals/run.sh: they must reference
# host-specific tokens (CLAUDE_PLUGIN_ROOT) that core's purity suite bans from
# every file under core/. They live here, and only here.
#
# This runner takes NO arguments — it always runs every case under cases/.
# Unknown argv is rejected rather than silently ignored, matching core's
# behaviour on an unrecognized --suite.
#
# Exit codes: 0 all cases passed; 1 a case failed, zero cases were discovered
# (never a silent empty pass), or any argument was passed.

set -uo pipefail

if [ $# -ne 0 ]; then
  echo "error: adapter suite takes no arguments (got: $*) — it always runs every case under cases/" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CASES_DIR="$SCRIPT_DIR/cases"

cases=()
while IFS= read -r c; do
  [ -n "$c" ] && cases+=("$c")
done < <(find "$CASES_DIR" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)

printf 'suite=adapter cases=%d\n' "${#cases[@]}"

if [ ${#cases[@]} -eq 0 ]; then
  echo "error: adapter suite discovered zero cases in $CASES_DIR — an empty suite is a failure, not a pass" >&2
  exit 1
fi

failed=0
for case_file in "${cases[@]}"; do
  name="$(basename "$case_file" .sh)"
  if bash "$case_file" "$ADAPTER_DIR"; then
    printf '  PASS adapter/%s\n' "$name"
  else
    printf '  FAIL adapter/%s\n' "$name" >&2
    failed=$((failed + 1))
  fi
done

if [ "$failed" -ne 0 ]; then
  printf 'FAILED: %d failure(s) across %d case(s)\n' "$failed" "${#cases[@]}" >&2
  exit 1
fi

printf 'OK: %d case(s) passed\n' "${#cases[@]}"
