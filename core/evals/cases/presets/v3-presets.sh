#!/usr/bin/env bash
# Presets suite over the V3 preset in core/presets/.
#
# brainstorm is the only preset selecting the `divergent` playbook and the only
# one whose session runs in two phases. Style and fidelity are asserted as
# VALUES through the checker's own parser: `check-preset-schema.sh` on its own
# validates key-set and enum membership only, so `style: socratic, fidelity:
# low` passes it identically and asserts nothing about this preset.
#
# The convergence phase is the hazard this case pins shut. The engine's style
# enum is closed at exactly five members, so "divergent-then-convergent" has to
# land as a PHASE inside the divergent playbook body — never as a sixth enum
# member and never as a second style field. `framing` is the four-key schema's
# only free-prose channel, so it is where the two-phase shape is declared, and
# it is read here as a FIELD rather than grepped out of the file: a file-scoped
# grep goes green on a preset whose declared frontmatter says something else, as
# long as the old sentence survives somewhere in the body.

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

# `preset_field` and `check_preset` are shared with the V1 and V2 suites and
# live in cases/lib.sh; they read CHECKER, PRESETS_DIR and STYLES, all set above.

# V3 assignment: brainstorm=divergent/mid.
check_preset brainstorm divergent mid

BRAINSTORM="$PRESETS_DIR/brainstorm.md"

# The two-phase shape, asserted against the parsed `framing` value.
assert_field_has() {
  # assert_field_has <file> <key> <fixed-substring> <label>
  case "$(preset_field "$1" "$2")" in
    *"$3"*) ;;
    *) fail "brainstorm $2 does not carry: $4" ;;
  esac
}

assert_field_has "$BRAINSTORM" framing \
  'Widen the field of possible answers before narrowing it' \
  'the divergent-then-convergent shape'
assert_field_has "$BRAINSTORM" framing \
  'without judging them' \
  'judgment held open during generation'

# The output contract is a design record, not a bare signal list: the losing
# options and their reasons are the part a convergence phase exists to leave
# behind, and a contract that drops them describes a different preset.
assert_field_has "$BRAINSTORM" output_contract \
  'design record' \
  'the design-doc artifact'
assert_field_has "$BRAINSTORM" output_contract \
  'every rejected option with the reason it lost' \
  'rejected options recorded with their reasons'

# Negative on the enum itself: convergence is a phase inside the divergent
# playbook. A sixth style named for it would satisfy every positive assertion
# above while breaking the closed enum this preset was built against.
printf '%s\n' "$STYLES" | grep -qxF -- convergent \
  && fail "the engine style enum gained a 'convergent' member — convergence is a phase of the divergent playbook, not a style"

# The stop rule stays engine-owned: the preset NAMES the rule its divergence
# phase stops on (contract/engine-techniques.sh resolves that reference to a
# real heading), and carries no stop_rule_override key — the schema checker
# rejects one, and this pins the prose reference that replaces it.
assert_file_has_fixed "$BRAINSTORM" '### Stop at a saturated option space' \
  'brainstorm names the engine stop rule its divergence phase uses'

# Output contract names the signals the preset emits.
for signal in RESOLVED_TERM ADR_CANDIDATE HANDOFF_SUGGESTION; do
  assert_file_has_fixed "$BRAINSTORM" "$signal" "brainstorm output_contract: $signal"
done

case_exit
