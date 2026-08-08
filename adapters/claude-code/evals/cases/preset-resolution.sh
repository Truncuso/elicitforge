#!/usr/bin/env bash
# The front door's documented address — ${CLAUDE_PLUGIN_ROOT}/presets/<name>.md —
# must resolve, through the adapter's own vendored presets/ directory, to a
# readable preset whose frontmatter actually PARSES as YAML, for every shipped
# preset.
#
# The expected name list is cross-checked against the REAL core/presets/*.md
# listing, so adding, renaming, or dropping a preset fails this case instead of
# silently drifting away from the shipped names.
#
# The address itself is EXTRACTED from SKILL.md's own `## Resolution` block
# rather than re-declared here: a drifted published address must fail this case,
# not pass it against a private copy of the literal.

ADAPTER_DIR="$1"
REPO_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"
. "$REPO_ROOT/core/evals/cases/lib.sh"

# The host enumerates plugin skills from <plugin-root>/skills/<name>/SKILL.md.
# A root-level SKILL.md is never visited, so the path itself is an assertion.
SKILL="$ADAPTER_DIR/skills/interview/SKILL.md"
[ -r "$SKILL" ] || { echo "    unreadable (not at a discoverable component path): $SKILL" >&2; exit 1; }

EXPECTED_ADDRESS='${CLAUDE_PLUGIN_ROOT}/presets/<name>.md'

# The published address, read out of the fenced block under `## Resolution`.
published="$(awk '/^## Resolution/{inside=1; next} inside && /^## /{inside=0} inside' "$SKILL" \
  | grep -F '${CLAUDE_PLUGIN_ROOT}/presets/' | head -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

if [ "$published" != "$EXPECTED_ADDRESS" ]; then
  fail "published preset address drifted — expected [$EXPECTED_ADDRESS] got [$published]"
  published="$EXPECTED_ADDRESS"
fi

# The plugin's skill name is part of the address contract: a rename breaks every
# caller that invokes the front door by name.
assert_file_has_fixed "$SKILL" 'name: interview' 'front door skill name'

EXPECTED_PRESETS='capture-intake
harden-facets
spec-grill
wayfind-probe
quiz-back
teach-back'

actual="$(find "$REPO_ROOT/core/presets" -maxdepth 1 -type f -name '*.md' -printf '%f\n' 2>/dev/null | sed 's/\.md$//' | sort)"
assert_set_equals "shipped preset set under core/presets" "$EXPECTED_PRESETS" "$actual"

# Resolve each preset the way the host does: through the exported plugin root,
# substituting the bare name into the address string extracted above.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  (
    export CLAUDE_PLUGIN_ROOT="$ADAPTER_DIR"
    target="$(printf '%s' "$published" \
      | sed "s|\\\${CLAUDE_PLUGIN_ROOT}|$CLAUDE_PLUGIN_ROOT|; s|<name>|$name|")"

    [ -r "$target" ] || { echo "    unresolvable through plugin root: $target" >&2; exit 1; }

    # Frontmatter must PARSE, not merely be non-blank: a preset whose YAML is
    # broken loads with empty metadata and is functionally dead, while a
    # non-blank check would call it healthy.
    python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]).read().split("---")[1]) or sys.exit(1)' \
      "$target" 2>/dev/null \
      || { echo "    frontmatter does not parse as YAML: ${name}.md" >&2; exit 1; }
  ) || fail "preset '$name' did not resolve to a readable file with parseable frontmatter"
done <<< "$EXPECTED_PRESETS"

# The resolution mechanism is a REAL directory at the plugin root, not a symlink
# out to core/: the host installs this directory alone, so a link leaving it
# resolves in the source tree and dangles on every real install. The forking risk
# the symlink used to prevent is now carried by vendored-presets-sync.sh's drift
# diff, which also owns the plugin-root closure assertion.
{ [ -d "$ADAPTER_DIR/presets" ] && [ ! -L "$ADAPTER_DIR/presets" ]; } \
  || fail "adapter presets/ must be a real, committed directory (not a symlink)"

# The second, redundant address is gone: the front door resolves through
# ${CLAUDE_PLUGIN_ROOT}/presets/ only, so a per-skill copy would be a second
# source of truth with nothing pointing at it.
{ [ ! -e "$ADAPTER_DIR/skills/interview/presets" ] && [ ! -L "$ADAPTER_DIR/skills/interview/presets" ]; } \
  || fail "skills/interview/presets still exists — the front door resolves through the plugin root only"

# The single cheapest end-to-end check: the host's own plugin validator. It is
# what catches unparseable frontmatter and an undiscoverable component path.
if command -v claude >/dev/null 2>&1; then
  claude plugin validate --strict "$ADAPTER_DIR" > "${TMPDIR:-/tmp}/pv.$$" 2>&1
  if ! grep -qF 'Validation passed' "${TMPDIR:-/tmp}/pv.$$"; then
    fail "claude plugin validate --strict did not pass:"
    sed 's/^/      /' "${TMPDIR:-/tmp}/pv.$$" >&2
  fi
  rm -f "${TMPDIR:-/tmp}/pv.$$"
else
  echo "    note: claude CLI unavailable — plugin validation skipped" >&2
fi

case_exit
