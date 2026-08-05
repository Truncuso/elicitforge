#!/usr/bin/env bash
# Fitness function: core/** must stay harness-agnostic. Every fixed string in
# the denylist names a host-specific tool, path, or env var that must never
# appear under core/.
#
# The denylist ships base64-encoded (denylist.b64) on purpose: stored as plain
# text it would itself be the only literal occurrence of the banned tokens under
# core/, defeating any external scan of the tree. Read it with
# `base64 -d denylist.b64`; edit by decoding, editing, re-encoding.

CORE_DIR="$1"
CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$(cd "$CASE_DIR/.." && pwd)/lib.sh"

ENCODED="$CASE_DIR/denylist.b64"
[ -s "$ENCODED" ] || { echo "    denylist.b64 missing or empty" >&2; exit 1; }

DENYLIST="$(mktemp)"
trap 'rm -f "$DENYLIST"' EXIT
base64 -d "$ENCODED" > "$DENYLIST" || { echo "    could not decode denylist.b64" >&2; exit 1; }
[ -s "$DENYLIST" ] || { echo "    decoded denylist is empty" >&2; exit 1; }

scanned=0
while IFS= read -r file; do
  scanned=$((scanned + 1))
  while IFS= read -r hit; do
    fail "host-specific token in ${file#"$CORE_DIR"/}: $hit"
  done < <(grep -nFf "$DENYLIST" "$file")
done < <(find "$CORE_DIR" -type f | sort)

[ "$scanned" -gt 0 ] || fail "purity scan matched no files under $CORE_DIR"

case_exit
