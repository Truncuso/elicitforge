#!/usr/bin/env bash
# Two properties of the vendored preset copy, which only hold together:
#
#   closure — no path under the plugin root resolves outside it. The host
#     materializes ONLY this directory (a marketplace `git-subdir` source fetches
#     the declared `path` subtree and nothing else), so `core/` is absent at
#     runtime and any outward-pointing symlink dangles on every real install
#     while resolving perfectly in a full source clone — a defect structurally
#     invisible to any check run from the source tree.
#
#   no drift — closure is bought with a second copy of every core file the front
#     door points at (core/presets/*.md, core/engine.md,
#     core/references/signals-contract.md), so each copy must be a GENERATED
#     artifact, not a fork. `core/` is the single source of truth; this case is
#     what makes that true rather than aspirational.
#
# Symlink closure alone is not enough: a plugin root that merely contains no
# outward symlink can still POINT — in prose the host reads — at content only
# `core/` carries. Every vendored file below is content the runtime install must
# be able to read at ${CLAUDE_PLUGIN_ROOT}.
#
# All assertions are guarded against vacuity: a plugin root with no files, a
# preset pair of two empty directories, or an empty vendored file fails instead
# of passing silently.

ADAPTER_DIR="$1"
REPO_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"
. "$REPO_ROOT/core/evals/cases/lib.sh"

CORE_PRESETS="$REPO_ROOT/core/presets"
VENDORED="$ADAPTER_DIR/presets"

# -- closure ------------------------------------------------------------------

scanned=0
while IFS= read -r f; do
  scanned=$((scanned + 1))
done < <(find "$ADAPTER_DIR" -type f)
[ "$scanned" -gt 0 ] || fail "closure scan matched no files under the plugin root — the check would pass vacuously"

while IFS= read -r link; do
  [ -n "$link" ] || continue
  # readlink -m, not -f: a symlink whose target does not exist is exactly the
  # failure this case exists to catch, and -f resolves such a link to nothing.
  target="$(readlink -m "$link")"
  case "$target" in
    "$ADAPTER_DIR"/*) ;;
    *) fail "symlink escapes the plugin root: ${link#"$REPO_ROOT"/} -> $target" ;;
  esac
  # A symlink that stays inside the plugin root but points at a path that does
  # not exist is not "closure" either — it breaks at runtime just like an
  # outward-pointing one, and readlink -m alone does not catch it.
  [ -e "$target" ] || fail "symlink under the plugin root has a dangling target: ${link#"$REPO_ROOT"/} -> $target"
done < <(find "$ADAPTER_DIR" -type l)

# -- no drift -----------------------------------------------------------------

[ -d "$CORE_PRESETS" ] && [ ! -L "$CORE_PRESETS" ] \
  || fail "core/presets is not a real directory"
[ -d "$VENDORED" ] && [ ! -L "$VENDORED" ] \
  || fail "the vendored copy at adapters/claude-code/presets is not a real directory"

core_count="$(find "$CORE_PRESETS" -maxdepth 1 -type f -name '*.md' | wc -l)"
[ "$core_count" -gt 0 ] || fail "core/presets holds no presets — a drift diff of two empty trees is not a pass"

if ! diff_out="$(diff -r "$CORE_PRESETS" "$VENDORED" 2>&1)"; then
  fail "vendored presets have drifted from core/presets:"
  printf '%s\n' "$diff_out" | sed 's/^/      /' >&2
fi

# -- no drift: the single vendored files the front door reads ------------------
#
# "<core-relative path>|<plugin-root-relative path>" — the engine and the signal
# grammar are as load-bearing at runtime as the presets are.
for pair in \
  "engine.md|engine.md" \
  "references/signals-contract.md|references/signals-contract.md" \
  "references/interview-conduct.md|references/interview-conduct.md"
do
  src="$REPO_ROOT/core/${pair%%|*}"
  dst="$ADAPTER_DIR/${pair##*|}"
  [ -f "$src" ] && [ -s "$src" ] \
    || fail "core source is missing or empty: core/${pair%%|*}"
  [ -f "$dst" ] && [ ! -L "$dst" ] && [ -s "$dst" ] \
    || fail "vendored copy is missing, empty, or a symlink: ${pair##*|} (the runtime install would have nothing to read)"
  if ! diff_out="$(diff "$src" "$dst" 2>&1)"; then
    fail "vendored ${pair##*|} has drifted from core/${pair%%|*}:"
    printf '%s\n' "$diff_out" | sed 's/^/      /' >&2
  fi
done

case_exit
