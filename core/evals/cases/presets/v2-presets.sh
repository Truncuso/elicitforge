#!/usr/bin/env bash
# Presets suite over the V2 presets in core/presets/.
#
# Per preset: the schema checker accepts it, its style names a member of the
# engine's closed enum (core/engine.md, not a list copied here), and its style
# and fidelity carry the V2 assignments. `fidelity: mid` for all three — each
# produces a durable record a caller is held to.
#
# quiz-back and teach-back both select the single `teachback` style: the enum
# stays closed at five members and the two DIRECTIONS inside that one playbook
# are distinguishable only through `framing`, which is the four-key schema's
# only free-prose channel. The per-preset direction assertions below are what
# make that distinction gated rather than merely intended — a teach-back preset
# rewritten to grade the learner fails here. They read the `framing` FIELD, not
# the file: a file-scoped grep goes green on a preset whose declared contract
# says the opposite, as long as the old sentence survives somewhere in the body.
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

# `preset_field` and `check_preset` are shared with the V1 suite and live in
# cases/lib.sh; they read CHECKER, PRESETS_DIR and STYLES, all set above.

# V2 assignments: wayfind-probe=socratic/mid, quiz-back=teachback/mid,
# teach-back=teachback/mid.
check_preset wayfind-probe socratic mid
check_preset quiz-back teachback mid
check_preset teach-back teachback mid

# Direction prose: the only channel distinguishing the two `teachback` presets.
# Asserted against the parsed `framing` value, through the checker's own reader.
assert_framing_has() {
  # assert_framing_has <preset-name> <fixed-substring> <label>
  local name="$1" needle="$2" label="$3"
  case "$(preset_field "$PRESETS_DIR/$name.md" framing)" in
    *"$needle"*) ;;
    *) fail "$name framing does not carry: $label" ;;
  esac
}

assert_framing_has wayfind-probe 'one grilling ticket on a wayfind decision map' \
  'one grilling ticket per probe'
assert_framing_has quiz-back 'retrieval practice that grades the recall' \
  'the grading quiz-back direction'
assert_framing_has teach-back 'never tests and never scores the learner' \
  'the no-grading teach-back direction'

# Negative leg on the same field: a positive substring alone cannot detect
# contradictory text added BESIDE it. Grading belongs to the quiz-back direction
# alone, so grading vocabulary has no business in teach-back's declared contract
# in any form — the file states the invariant with "never tests and never scores
# the learner" and needs the word grade/grading/graded nowhere.
# Match the words, not the stem: a bare *grad* also fires on "gradually" and
# "upgrade", which carry no grading claim.
case "$(preset_field "$PRESETS_DIR/teach-back.md" framing)" in
  *grade*|*grading*|*graded*|*grades*)
    fail "teach-back framing uses grading vocabulary — grading belongs to the quiz-back direction alone" ;;
esac

# The stop rules stay engine-owned: each teachback preset NAMES the rule it
# stops on, and neither carries a stop_rule_override key (the schema checker
# rejects one, and this pins the prose reference that replaces it).
assert_file_has_fixed "$PRESETS_DIR/quiz-back.md" '### Stop at a settled recall profile' \
  'quiz-back names the engine stop rule it uses'
assert_file_has_fixed "$PRESETS_DIR/teach-back.md" 'Stop at a closed gap register' \
  'teach-back names the engine stop rule it uses'

# Output contracts name the signals each preset emits.
for preset in wayfind-probe quiz-back teach-back; do
  for signal in RESOLVED_TERM ADR_CANDIDATE HANDOFF_SUGGESTION; do
    assert_file_has_fixed "$PRESETS_DIR/$preset.md" "$signal" "$preset output_contract: $signal"
  done
done

# The shipped set, checked against the live listing rather than assumed. The
# expected side is lib.sh's single literal, shared with the adapter's
# preset-resolution case, so a new preset is one edit rather than three.
assert_set_equals "v2 preset set under core/presets" \
  "$(expected_preset_set)" \
  "$(find "$PRESETS_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' 2>/dev/null | sed 's/\.md$//' | sort)"

case_exit
