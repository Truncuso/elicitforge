#!/usr/bin/env bash
# Asserts the seven interview techniques survive verbatim in core/engine.md,
# plus the single unattended: rule and the closed five-member style enum.
# Fixed-string (grep -F) assertions on distinctive full sentences — a
# rewritten-from-memory engine must fail these.

CORE_DIR="$1"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

ENGINE="$CORE_DIR/engine.md"
[ -f "$ENGINE" ] || { echo "    missing $ENGINE" >&2; exit 1; }

# 1. hypothesis + confidence opener
assert_file_has_fixed "$ENGINE" 'CONFIDENCE: ~35% — missing:' 'confidence-number opener'
# 2. want-vs-should-want probe
assert_file_has_fixed "$ENGINE" "If you didn't have to justify this to anyone, what would you actually want?" 'want-vs-should-want probe'
# 3. predictive-confidence stopping rule
assert_file_has_fixed "$ENGINE" "can I predict the user's reaction to the next three questions" 'predictive-confidence stop'
# 4. glossary challenge
assert_file_has_fixed "$ENGINE" "Your glossary defines 'cancellation'" 'glossary challenge'
# 5. concrete-scenario stress-test
assert_file_has_fixed "$ENGINE" 'Invent scenarios that probe edge cases' 'concrete-scenario stress-test'
# 6. code cross-reference
assert_file_has_fixed "$ENGINE" 'If you find a contradiction, surface it' 'code cross-reference'
# 7. structured output signals
for signal in RESOLVED_TERM ADR_CANDIDATE HANDOFF_SUGGESTION; do
  assert_file_has_fixed "$ENGINE" "$signal" "output signal $signal"
done

# The single unattended: rule, both behaviors.
assert_file_has_fixed "$ENGINE" '## unattended:' 'unattended rule section'
assert_file_has_fixed "$ENGINE" 'resumable state sink' 'unattended PARK condition'
assert_file_has_fixed "$ENGINE" 'degrade-to-assumptions' 'unattended degrade behavior'

# Closed style enum — exactly these five, no more, no fewer.
assert_set_equals 'style enum' \
  "$(printf 'socratic\nadversarial\nrapid\nteachback\ndivergent\n')" \
  "$(engine_styles "$ENGINE")"

case_exit
