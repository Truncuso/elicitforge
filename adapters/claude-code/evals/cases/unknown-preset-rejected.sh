#!/usr/bin/env bash
# Negative case: an unknown preset name must be REJECTED, not silently
# substituted. The behaviour is documented instruction, so the assertion is on
# the front door's documented halt language — plus a check that the front door
# carrying that language is actually loadable by the host, so this case cannot
# go green on prose that never reaches a session.

ADAPTER_DIR="$1"
REPO_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"
. "$REPO_ROOT/core/evals/cases/lib.sh"

SKILL="$ADAPTER_DIR/skills/interview/SKILL.md"
[ -r "$SKILL" ] || { echo "    unreadable: $SKILL" >&2; exit 1; }

assert_file_has_fixed "$SKILL" '## Unknown or missing preset' 'unknown/missing preset section'
assert_file_has_fixed "$SKILL" '**Halt.** Do not start the interview.' 'explicit halt instruction'
assert_file_has_fixed "$SKILL" 'Never silently fall back to a default preset' 'no-silent-fallback rule'

# An unknown name must in fact have nothing to resolve to.
(
  export CLAUDE_PLUGIN_ROOT="$ADAPTER_DIR"
  [ ! -e "${CLAUDE_PLUGIN_ROOT}/presets/definitely-not-a-preset.md" ]
) || fail "an unknown preset name unexpectedly resolved to an existing file"

# ...and a known name must, so the check above is not vacuously true of any
# directory whatsoever.
(
  export CLAUDE_PLUGIN_ROOT="$ADAPTER_DIR"
  [ -r "${CLAUDE_PLUGIN_ROOT}/presets/spec-grill.md" ]
) || fail "a known preset name failed to resolve through the plugin root"

# The halt language only binds if the host can load this front door at all.
if command -v claude >/dev/null 2>&1; then
  out="$(claude plugin validate --strict "$ADAPTER_DIR" 2>&1)"
  printf '%s' "$out" | grep -qF 'Validation passed' \
    || { fail "claude plugin validate --strict did not pass:"; printf '%s\n' "$out" | sed 's/^/      /' >&2; }
else
  echo "    note: claude CLI unavailable — plugin validation skipped" >&2
fi

case_exit
