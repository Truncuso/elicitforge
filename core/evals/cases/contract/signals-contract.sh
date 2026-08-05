#!/usr/bin/env bash
# Asserts the frozen signals contract: an anchored contract_version of exactly
# 1.0 (so 1.0.5 or 1.05 fails), the exact five-member HANDOFF_SUGGESTION enum
# (a dropped or silently added member fails), and a sink + sink-absent degrade
# declaration for every declared signal type.

CORE_DIR="$1"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

CONTRACT="$CORE_DIR/references/signals-contract.md"
[ -f "$CONTRACT" ] || { echo "    missing $CONTRACT" >&2; exit 1; }

grep -qE '^contract_version: 1\.0$' "$CONTRACT" \
  || fail "contract_version is not exactly 1.0 (anchored match failed)"

assert_set_equals 'HANDOFF_SUGGESTION enum' \
  "$(printf 'research\nexpert:<role>\nuser-judgment\nhigh-fidelity\ndeferred\n')" \
  "$(contract_handoff_members "$CONTRACT")"

signals="$(contract_signal_types "$CONTRACT")"
assert_set_equals 'signal types' \
  "$(printf 'RESOLVED_TERM\nADR_CANDIDATE\nHANDOFF_SUGGESTION\n')" \
  "$signals"

# Every signal type declares both a sink and a sink-absent degrade path.
declared_sinks=$(grep -c '^- \*\*Sink\*\* —' "$CONTRACT")
declared_degrades=$(grep -c '^- \*\*Sink absent (degrade)\*\* —' "$CONTRACT")
expected=$(printf '%s\n' "$signals" | sed '/^$/d' | wc -l)
[ "$declared_sinks" -eq "$expected" ] \
  || fail "expected $expected sink declarations, found $declared_sinks"
[ "$declared_degrades" -eq "$expected" ] \
  || fail "expected $expected sink-absent degrade declarations, found $declared_degrades"

case_exit
