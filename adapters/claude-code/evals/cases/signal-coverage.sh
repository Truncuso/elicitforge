#!/usr/bin/env bash
# The adapter's declared signal map must cover EXACTLY the signal types the
# contract declares — no dropped signal, no invented one.
#
# The adapter's declaration lives in SKILL.md's own `description:` frontmatter
# (the triggering surface a caller reads); the contract's declaration is read
# live from core/references/signals-contract.md §Signal types. A signal added to
# or removed from the contract fails this case until the front door follows.

ADAPTER_DIR="$1"
REPO_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"
. "$REPO_ROOT/core/evals/cases/lib.sh"

SKILL="$ADAPTER_DIR/skills/interview/SKILL.md"
CONTRACT="$REPO_ROOT/core/references/signals-contract.md"
[ -r "$SKILL" ] || { echo "    unreadable: $SKILL" >&2; exit 1; }
[ -r "$CONTRACT" ] || { echo "    unreadable: $CONTRACT" >&2; exit 1; }

contract_types="$(contract_signal_types "$CONTRACT" | sort)"
[ -n "$contract_types" ] || fail "contract declared no signal types — parser or contract drifted"

# The signals the front door's description enumerates, read through a real YAML
# parse so a folded/quoted scalar is handled the same way the host handles it.
declared="$(python3 -c '
import re, sys, yaml
fm = yaml.safe_load(open(sys.argv[1]).read().split("---")[1])
desc = fm.get("description") or ""
print("\n".join(sorted(set(re.findall(r"\b[A-Z]+(?:_[A-Z]+)+\b", desc)))))
' "$SKILL" | sort)"

assert_set_equals "adapter signal map vs contract §Signal types" "$contract_types" "$declared"

case_exit
