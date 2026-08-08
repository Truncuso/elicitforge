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

# `preset_field` and `check_preset` are shared with the V1 suite and live in
# cases/lib.sh; they read CHECKER, PRESETS_DIR and STYLES, all set above.

# V2 assignments: wayfind-probe=socratic/mid, quiz-back=teachback/mid,
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
