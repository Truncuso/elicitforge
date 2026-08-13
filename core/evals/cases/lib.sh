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

# The shipped preset set, as a LITERAL — deliberately NOT derived from the
# presets/ listing, because a set-equality check whose expected side is read
# from the directory under test passes for any directory whatsoever. This is
# the single editable copy of the list: adding a preset means editing it here,
# and every suite comparing against it stays red until it does.
expected_preset_set() {
  printf '%s\n' capture-intake harden-facets spec-grill wayfind-probe quiz-back teach-back brainstorm
}

# --- shared preset readers ---------------------------------------------------
#
# Both preset suites need these two helpers. A second copy of them is the exact
# hazard preset_field itself exists to prevent, one level up: two readers over
# one schema drift, and the suite that drifted goes green over a file the
# validator gating it would reject. They read three globals the calling case
# sets before the first call:
#
#   CHECKER       path to evals/check-preset-schema.sh
#   PRESETS_DIR   directory holding the preset files under test
#   STYLES        the engine's live style enum, one per line (engine_styles)

# Value of a top-level frontmatter key, read through the checker's own parser
# (--print-fields) rather than a second mini-parser here.
preset_field() {
  # preset_field <file> <key>
  bash "$CHECKER" --print-fields "$1" | awk -F'\t' -v key="$2" '$1 == key { print $2; exit }'
}

check_preset() {
  # check_preset <name> <expected-style> <expected-fidelity>
  local name="$1" want_style="$2" want_fidelity="$3"
  local file="$PRESETS_DIR/$name.md"

  if [ ! -f "$file" ]; then
    fail "$name: missing $file"
    return
  fi

  bash "$CHECKER" "$file" >/dev/null || fail "$name: rejected by the preset schema checker"

  local style fidelity framing contract
  style="$(preset_field "$file" style)"
  fidelity="$(preset_field "$file" fidelity)"
  framing="$(preset_field "$file" framing)"
  contract="$(preset_field "$file" output_contract)"

  printf '%s\n' "$STYLES" | grep -qxF -- "$style" \
    || fail "$name: style '$style' is not a member of the engine's closed enum"
  [ "$style" = "$want_style" ] || fail "$name: style is '$style', expected '$want_style'"
  [ "$fidelity" = "$want_fidelity" ] || fail "$name: fidelity is '$fidelity', expected '$want_fidelity'"

  # Framing is prose carrying purpose, never an enum: require real prose, not a
  # one-word placeholder.
  [ "${#framing}" -ge 60 ] || fail "$name: framing is not prose carrying purpose (${#framing} chars)"
  [ "${#contract}" -ge 60 ] || fail "$name: output_contract does not state a real signal contract (${#contract} chars)"
}
