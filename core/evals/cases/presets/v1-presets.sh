#!/usr/bin/env bash
# Presets suite over the real V1 presets in core/presets/.
#
# Per preset: the schema checker accepts it, its style names a member of the
# engine's closed enum (core/engine.md, not a list copied here), its style and
# fidelity carry the V1 assignments, and its framing and output_contract carry
# the purpose and signal contract that preset exists for.
#
# Exercised in both directions: every fixture under fixtures/invalid/ must be
# REJECTED by the schema checker, so a permissive validator that accepts
# anything fails this case rather than passing it vacuously.

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

# The checker hardcodes its own style enum. Assert it equals the engine's live
# `## Style playbooks` headings, so neither side can gain or lose a style while
# the suite stays green.
assert_set_equals "style enum (engine vs schema checker)" \
  "$STYLES" "$(bash "$CHECKER" --print-style-enum)"

# The checker's inline fixture corpus is the only coverage for several rejection
# rules, so it runs from the standing harness rather than by hand.
bash "$CHECKER" --self-test >/dev/null || fail "check-preset-schema.sh --self-test failed"

# `preset_field` and `check_preset` are shared with the V2 suite and live in
# cases/lib.sh; they read CHECKER, PRESETS_DIR and STYLES, all set above.

# V1 assignments (wp-02 overview): capture-intake=rapid/low, spec-grill and
# harden-facets=socratic/mid.
check_preset capture-intake rapid low
check_preset spec-grill socratic mid
check_preset harden-facets socratic mid

# Per-preset framing + output_contract content: distinctive phrases, so a
# preset rewritten into generic filler fails.
assert_file_has_fixed "$PRESETS_DIR/capture-intake.md" 'Breadth over depth' 'capture-intake framing: breadth-first intake'
assert_file_has_fixed "$PRESETS_DIR/spec-grill.md" 'shareable build' 'spec-grill framing: shareable-build purpose'
assert_file_has_fixed "$PRESETS_DIR/harden-facets.md" 'facet by facet' 'harden-facets framing: facet-by-facet hardening'

# Output contracts name the signals each preset emits. capture-intake is a rapid
# intake pass: RESOLVED_TERM and HANDOFF_SUGGESTION are its working signals; the
# grilling presets carry all three.
for signal in RESOLVED_TERM HANDOFF_SUGGESTION; do
  assert_file_has_fixed "$PRESETS_DIR/capture-intake.md" "$signal" "capture-intake output_contract: $signal"
done
for preset in spec-grill harden-facets; do
  for signal in RESOLVED_TERM ADR_CANDIDATE HANDOFF_SUGGESTION; do
    assert_file_has_fixed "$PRESETS_DIR/$preset.md" "$signal" "$preset output_contract: $signal"
  done
done

# Negative direction: every invalid fixture must be rejected.
invalid_count=0
for f in "$CASE_DIR"/fixtures/invalid/*.md; do
  [ -e "$f" ] || continue
  invalid_count=$((invalid_count + 1))
  if bash "$CHECKER" "$f" >/dev/null 2>&1; then
    fail "$(basename "$f"): accepted by the schema checker, expected rejection"
  fi
done
[ "$invalid_count" -gt 0 ] || fail "no invalid fixtures found in $CASE_DIR/fixtures/invalid"

case_exit
