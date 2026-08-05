# Shared assertions for eval cases. Sourced, never executed as a case
# (it lives outside every suite directory, so it is never discovered).

set -uo pipefail

CASE_FAILURES=0

fail() {
  printf '    %s\n' "$*" >&2
  CASE_FAILURES=$((CASE_FAILURES + 1))
}

assert_file_has_fixed() {
  # assert_file_has_fixed <file> <fixed-string> [label]
  local file="$1" needle="$2" label="${3:-$2}"
  grep -qF -- "$needle" "$file" || fail "missing in $(basename "$file"): $label"
}

assert_set_equals() {
  # assert_set_equals <label> <expected-newline-list> <actual-newline-list>
  local label="$1" expected="$2" actual="$3"
  local e a
  e="$(printf '%s\n' "$expected" | sed '/^$/d' | sort)"
  a="$(printf '%s\n' "$actual" | sed '/^$/d' | sort)"
  if [ "$e" != "$a" ]; then
    fail "$label mismatch — expected [$(echo "$e" | tr '\n' ' ')] got [$(echo "$a" | tr '\n' ' ')]"
  fi
}

case_exit() {
  [ "$CASE_FAILURES" -eq 0 ] && return 0
  return 1
}

# Closed style enum, read from the engine's own Style playbooks section.
engine_styles() {
  local engine="$1"
  awk '/^## Style playbooks/{inside=1; next} inside && /^## /{inside=0} inside && /^### /{print $2}' "$engine"
}

# Frozen HANDOFF_SUGGESTION enum members, read from the contract's table.
contract_handoff_members() {
  local contract="$1"
  awk '/^## Frozen `HANDOFF_SUGGESTION` enum/{inside=1; next} inside && /^## /{inside=0} inside' "$contract" \
    | sed -n 's/^| `\([^`]*\)` |.*/\1/p'
}

# Signal type names declared by the contract.
contract_signal_types() {
  local contract="$1"
  awk '/^## Signal types/{inside=1; next} inside && /^## /{inside=0} inside' "$contract" \
    | sed -n 's/^### `\([^`]*\)`.*/\1/p'
}
