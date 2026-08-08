#!/usr/bin/env bash
# Presets suite over the V2 presets in core/presets/.
#
# Per preset: the schema checker accepts it, its style names a member of the
# engine's closed enum (core/engine.md, not a list copied here), and its style
# and fidelity carry the V2 assignments (wp-08 D4). `fidelity: mid` for all
# three — each produces a durable record a caller is held to.
#
# quiz-back and teach-back both select the single `teachback` style: the enum
# stays closed at five members and the two DIRECTIONS inside that one playbook
# are distinguishable only through `framing`, which is the four-key schema's
# only free-prose channel. The per-preset direction assertions below are what
# make that distinction gated rather than merely intended — a teach-back preset
# rewritten to grade the learner fails here.
#
# The shipped preset set is checked by set equality against the live
# core/presets/ listing, so a seventh preset added without a case fails this
# suite instead of shipping unasserted.

CORE_DIR="$1"
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$(cd "$CASE_DIR/.." && pwd)/lib.sh"

ENGINE="$CORE_DIR/engine.md"
CHECKER="$CORE_DIR/evals/check-preset-schema.sh"
PRESETS_DIR="$CORE_DIR/presets"
[ -f "$ENGINE" ] || { echo "    missing $ENGINE" >&2; exit 1; }
[ -f "$CHECKER" ] || { echo "    missing $CHECKER" >&2; exit 1; }

STYLES="$(engine_styles "$ENGINE")"
[ -n "$STYLES" ] || { echo "    engine declares no styles" >&2; exit 1; }

# Value of a top-level frontmatter key, read through the checker's own parser
# (--print-fields) rather than a second mini-parser here: a suite that reads a
# preset differently from the validator that gates it can go green over a file
# neither one really accepts.
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

# V2 assignments (wp-08 D4): wayfind-probe=socratic/mid, quiz-back=teachback/mid,
# teach-back=teachback/mid.
check_preset wayfind-probe socratic mid
check_preset quiz-back teachback mid
check_preset teach-back teachback mid

# Direction prose: the only channel distinguishing the two `teachback` presets.
assert_file_has_fixed "$PRESETS_DIR/wayfind-probe.md" 'one grilling ticket on a wayfind decision map' \
  'wayfind-probe framing: one grilling ticket per probe'
assert_file_has_fixed "$PRESETS_DIR/quiz-back.md" 'retrieval practice that grades the recall' \
  'quiz-back framing: the grading quiz-back direction'
assert_file_has_fixed "$PRESETS_DIR/teach-back.md" 'never tests and never scores the learner' \
  'teach-back framing: the no-grading teach-back direction'

# The stop rules stay engine-owned: each teachback preset NAMES the rule it
# stops on, and neither carries a stop_rule_override key (the schema checker
# rejects one, and this pins the prose reference that replaces it).
assert_file_has_fixed "$PRESETS_DIR/quiz-back.md" 'Stop at predictive' \
  'quiz-back names the engine stop rule it uses'
assert_file_has_fixed "$PRESETS_DIR/teach-back.md" 'Stop at a closed gap register' \
  'teach-back names the engine stop rule it uses'

# Output contracts name the signals each preset emits.
for preset in wayfind-probe quiz-back teach-back; do
  for signal in RESOLVED_TERM ADR_CANDIDATE HANDOFF_SUGGESTION; do
    assert_file_has_fixed "$PRESETS_DIR/$preset.md" "$signal" "$preset output_contract: $signal"
  done
done

# The shipped set, checked against the live listing rather than assumed.
assert_set_equals "v2 preset set under core/presets" \
  "$(printf '%s\n' capture-intake harden-facets spec-grill wayfind-probe quiz-back teach-back)" \
  "$(find "$PRESETS_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' 2>/dev/null | sed 's/\.md$//' | sort)"

case_exit
