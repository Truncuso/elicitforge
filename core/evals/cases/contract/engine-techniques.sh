#!/usr/bin/env bash
# Asserts the interview techniques survive verbatim in core/engine.md, plus the
# named stop rules, the authored teachback playbook body, the single
# unattended: rule and the closed five-member style enum. Fixed-string (grep -F)
# assertions on distinctive full sentences — a rewritten-from-memory engine must
# fail these.
#
# The last leg is a RESOLVER rather than a fixed string: every `### <name>`
# reference, wherever it is written, must name a real heading in engine.md. A
# preset or a playbook body pointing at a deleted rule is a dangling reference
# in the instruction the model is handed at runtime, and no fixed-string pin
# catches the ones nobody thought to add.

CORE_DIR="$1"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

ENGINE="$CORE_DIR/engine.md"
[ -f "$ENGINE" ] || { echo "    missing $ENGINE" >&2; exit 1; }

# The engine's live `### ` headings. Assertions about a named subsection go
# through this list rather than through a substring scan of the file: every
# heading name also appears inside the backticked REFERENCES to it, so a
# substring pin stays green over a deleted heading whose references survive.
HEADINGS="$(sed -n 's/^### \(.*\)$/\1/p' "$ENGINE" | sort -u)"
[ -n "$HEADINGS" ] || { echo "    engine.md declares no ### headings" >&2; exit 1; }

assert_engine_heading() {
  # assert_engine_heading <name> [label]
  local name="$1" label="${2:-$1}"
  printf '%s\n' "$HEADINGS" | grep -qxF -- "$name" \
    || fail "engine.md has no '### $name' heading: $label"
}

# 1. hypothesis + confidence opener
assert_file_has_fixed "$ENGINE" 'CONFIDENCE: ~35% — missing:' 'confidence-number opener'
# 2. want-vs-should-want probe
assert_file_has_fixed "$ENGINE" "If you didn't have to justify this to anyone, what would you actually want?" 'want-vs-should-want probe'
# 3. predictive-confidence stopping rule
assert_file_has_fixed "$ENGINE" "can I predict the user's reaction to the next three questions" 'predictive-confidence stop'
# 3b. up-chain laddering — behaviour a preset selects BY NAME, so it has to live
# here. A preset that carries the technique in its own body instead is a
# declarative file describing behaviour, which is the layering this pins shut.
assert_engine_heading 'Ladder up-chain from a stated constraint' 'up-chain laddering technique'
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

# The named stop rules, by HEADING. The presets name these rules and stop on
# them; deleting one leaves every reference to it dangling while the style enum,
# which counts playbooks and not rules, stays green.
for heading in \
  'Stop at predictive confidence' \
  'Stop at a closed gap register' \
  'Stop at a settled recall profile'
do
  assert_engine_heading "$heading" 'named stop rule'
done

# The teachback playbook is AUTHORED, not a stub: one distinctive sentence from
# the body, and the negative that the stub it replaced is gone. The style-enum
# assertion above was already green against the stub heading, so it measures
# nothing about this.
assert_file_has_fixed "$ENGINE" 'Two named directions share this one playbook' 'teachback playbook body'
grep -qF -- '### teachback (stub)' "$ENGINE" \
  && fail "engine.md still carries '### teachback (stub)' — the playbook body did not replace it"

# Resolver: every `### <name>` reference in the engine and in the presets that
# select its rules must resolve to a real heading in engine.md.
#
# A reference split across a line break is invisible to a line-oriented scan, so
# an unterminated one is a failure in its own right rather than a silent skip.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  fail "named-subsection reference is not closed on its own line (write it unbroken): $hit"
done < <(grep -hn '`### [^`]*$' "$ENGINE" "$CORE_DIR"/presets/*.md)

refs="$(grep -ho '`### [^`]*`' "$ENGINE" "$CORE_DIR"/presets/*.md | sed 's/^`### //; s/`$//' | sort -u)"
[ -n "$refs" ] || fail "no named-subsection references found — the resolver would pass vacuously"
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  printf '%s\n' "$HEADINGS" | grep -qxF -- "$ref" \
    || fail "dangling reference: \`### $ref\` names no heading in engine.md"
done <<< "$refs"

case_exit
