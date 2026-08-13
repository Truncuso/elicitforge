#!/usr/bin/env bash
# A command wrapper's entire load-bearing content is the preset NAME it
# delegates with. Nothing asserted it: `claude plugin validate --strict` sees
# that the frontmatter parses and the file is discoverable, but not which preset
# the body names, so a wrapper repointed at the wrong preset passed both suites.
#
# Three properties, all driven off the live listings rather than a private copy:
#
#   set equality  every file under commands/ is covered here, so a new wrapper
#                 shipped without a case fails instead of going unasserted.
#   binding       a preset wrapper names its OWN preset, that name resolves to a
#                 real file under the plugin root, and it names no other.
#   carve-outs    /grill runs the front door with NO preset and /interview takes
#                 the preset from the caller — documented as such here, so
#                 "this one has no preset:" is an assertion rather than a gap.

ADAPTER_DIR="$1"
REPO_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"
. "$REPO_ROOT/core/evals/cases/lib.sh"

COMMANDS_DIR="$ADAPTER_DIR/commands"
VENDORED_PRESETS="$ADAPTER_DIR/presets"
[ -d "$COMMANDS_DIR" ] || { echo "    missing $COMMANDS_DIR" >&2; exit 1; }

# Wrappers that bind one fixed preset.
PRESET_WRAPPERS='quiz-back
teach-back
brainstorm'
# Wrappers that deliberately bind none.
OPEN_WRAPPERS='grill
interview'

ALL_WRAPPERS="$(printf '%s\n%s\n' "$PRESET_WRAPPERS" "$OPEN_WRAPPERS")"
SHIPPED="$(expected_preset_set)"

assert_set_equals "command wrappers under commands/" "$ALL_WRAPPERS" \
  "$(find "$COMMANDS_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' 2>/dev/null | sed 's/\.md$//' | sort)"

# Every wrapper is thin: it delegates to the front door instead of restating the
# resolution mechanics.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  f="$COMMANDS_DIR/$name.md"
  if [ ! -r "$f" ]; then
    fail "$name: unreadable wrapper at commands/$name.md"
    continue
  fi
  assert_file_has_fixed "$f" 'skills/interview/SKILL.md' "$name delegates to the front door"
done <<< "$ALL_WRAPPERS"

# A preset wrapper names its own preset, and only its own.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  f="$COMMANDS_DIR/$name.md"
  [ -r "$f" ] || continue

  assert_file_has_fixed "$f" "preset: $name" "$name binds preset: $name"
  [ -r "$VENDORED_PRESETS/$name.md" ] \
    || fail "$name: binds 'preset: $name', which resolves to no file under the plugin root"

  while IFS= read -r other; do
    { [ -n "$other" ] && [ "$other" != "$name" ]; } || continue
    grep -qF -- "preset: $other" "$f" \
      && fail "$name also binds 'preset: $other' — a wrapper names exactly one preset"
  done <<< "$SHIPPED"
done <<< "$PRESET_WRAPPERS"

# The carve-outs bind no shipped preset at all: /grill takes none and /interview
# passes the caller's through. A preset name baked into either is a silent
# default, which is the behaviour unknown-preset-rejected.sh exists to forbid.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  f="$COMMANDS_DIR/$name.md"
  [ -r "$f" ] || continue

  while IFS= read -r preset; do
    [ -n "$preset" ] || continue
    grep -qF -- "preset: $preset" "$f" \
      && fail "$name is documented as taking no fixed preset but binds 'preset: $preset'"
  done <<< "$SHIPPED"
done <<< "$OPEN_WRAPPERS"

case_exit
