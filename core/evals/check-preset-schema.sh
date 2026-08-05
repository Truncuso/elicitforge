#!/usr/bin/env bash
# Validates one or more preset files against the preset schema declared by
# spec.md's Interface Contract: frontmatter carrying exactly four fields —
#   style:           closed enum socratic|adversarial|divergent|teachback|rapid
#   fidelity:        closed enum low|mid|high
#   framing:         prose carrying purpose (learning / shareable-build /
#                    research / knowledge-work) — non-empty, not an enum
#   output_contract: which signals + required artifact sections — non-empty
#
# Presets are declarative config, never engine forks: any other frontmatter
# key is a violation, in particular `stop_rule_override` (a different stop
# rule is a second named engine rule, never a per-preset escape hatch) and any
# `purpose` enum field (nothing branches on it — framing is free prose, not an
# enum).
#
#   check-preset-schema.sh <preset.md> [<preset.md> ...]
#   check-preset-schema.sh --self-test
#   check-preset-schema.sh --print-style-enum      one style per line
#   check-preset-schema.sh --print-fields <file>   normalized key<TAB>value lines
#
# `--print-style-enum` exists so a caller can assert the checker's enum against
# the engine's live `## Style playbooks` headings instead of re-hardcoding it.
# `--print-fields` exposes THIS parser's normalized view of a file, so a caller
# never has to ship a second, subtly different frontmatter mini-parser.
#
# Exit codes: 0 all named presets validate (or self-test fully matches
# expectations); 1 any violation, missing file, or self-test mismatch.

set -uo pipefail

STYLE_ENUM="socratic adversarial divergent teachback rapid"
FIDELITY_ENUM="low mid high"
ALLOWED_KEYS="style fidelity framing output_contract"

# Scratch dir for --self-test. Script-scoped, not a function local, because the
# EXIT/INT/TERM traps that clean it up outlive the function frame.
SELF_TEST_TMP=""

usage() {
  printf 'usage: check-preset-schema.sh <preset.md> [<preset.md> ...]\n' >&2
  printf '       check-preset-schema.sh --self-test\n' >&2
  printf '       check-preset-schema.sh --print-style-enum\n' >&2
  printf '       check-preset-schema.sh --print-fields <preset.md>\n' >&2
}

in_list() {
  # in_list <needle> <space-separated haystack>
  local needle="$1" hay="$2" item
  for item in $hay; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

# Parses the frontmatter block (between the first two bare `---` lines) into a
# tagged record stream, one TAB-separated record per line. EVERY line inside the
# delimiters is accounted for — there is no silent-drop path, because a dropped
# line is a validator that fails open:
#
#   H<TAB><TAB>              the opening `---` was seen (frontmatter present)
#   C<TAB><TAB>              the closing `---` was seen (block terminated)
#   K<TAB>key<TAB>value      a recognized top-level `key: value` field
#   E<TAB>message<TAB>       a line (or the block) that cannot be accepted
#
# A file that does not open with a bare `---` yields nothing at all.
#
# Value normalization, in order: trim all leading/trailing whitespace; strip one
# layer of surrounding single or double quotes (dropping anything after the
# closing quote); on an unquoted value strip a trailing ` # comment`; trim again.
# So `style: "socratic"`, `style: socratic `, `style:  socratic`, and
# `style: socratic # comment` all normalize to `socratic`, while `framing: ""`
# and `framing:   ` normalize to the empty string and fail the non-empty gate.
#
# A value that is a bare block-scalar indicator (`|`, `>`, `|-`, `>2`, ...) is
# rejected rather than accepted as non-empty content, and the indented lines
# that follow it are consumed as its continuation — never re-read as fields,
# where they could smuggle a forbidden key past detection.
parse_frontmatter() {
  local file="$1"
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    BEGIN { q = sprintf("%c", 39) }

    NR == 1 && $0 != "---" { exit }
    NR == 1 { in_fm = 1; print "H\t\t"; next }

    in_fm && $0 == "---" { closed = 1; print "C\t\t"; exit }

    # Blank lines carry nothing either way, inside a block value or outside one.
    in_fm && /^[ \t]*$/ { next }

    # Indented lines are a continuation of the block value above them, and are
    # content of that (already rejected) value — never a field of their own.
    in_fm && /^[ \t]/ {
      if (block) next
      printf "E\tline %d is indented but continues no block value: %s\t\n", NR, trim($0)
      next
    }

    in_fm && match($0, /^[A-Za-z_][A-Za-z0-9_]*[ \t]*:/) {
      block = 0
      key = substr($0, 1, RLENGTH)
      sub(/[ \t]*:$/, "", key)
      val = trim(substr($0, RLENGTH + 1))

      if (val ~ /^[|>][-+]?[0-9]*$/) {
        printf "E\tfield %s uses a block scalar (%s); values must be single-line scalars\t\n", key, val
        block = 1
        next
      }

      if (substr(val, 1, 1) == "\"") {
        if (match(val, /^"[^"]*"/)) val = substr(val, 2, RLENGTH - 2)
      } else if (substr(val, 1, 1) == q) {
        if (match(val, "^" q "[^" q "]*" q)) val = substr(val, 2, RLENGTH - 2)
      } else {
        sub(/[ \t]+#.*$/, "", val)
      }

      printf "K\t%s\t%s\n", key, trim(val)
      next
    }

    in_fm {
      printf "E\tline %d is not a recognized `key: value` field: %s\t\n", NR, trim($0)
      next
    }

    END {
      if (in_fm && !closed) printf "E\tfrontmatter block has no closing --- line\t\n"
    }
  ' "$file"
}

# Prints the normalized `key<TAB>value` view of a file, so callers read fields
# through the same parser the checker validates with.
print_fields() {
  parse_frontmatter "$1" | awk -F'\t' '$1 == "K" { printf "%s\t%s\n", $2, $3 }'
}

# Validates a single preset file. Prints one violation per line to stderr.
# Returns 0 if the file validates, 1 otherwise.
validate_preset() {
  local file="$1" violations=0
  local style="" fidelity="" framing="" output_contract="" saw_keys="" tag key val

  if [ ! -f "$file" ]; then
    printf '    %s: file not found\n' "$file" >&2
    return 1
  fi

  local fm
  fm="$(parse_frontmatter "$file")"
  if [ -z "$fm" ]; then
    printf '    %s: no frontmatter block (must open with a bare --- line)\n' "$file" >&2
    return 1
  fi

  while IFS=$'\t' read -r tag key val; do
    case "$tag" in
      H|C) continue ;;
      E)
        printf '    %s: %s\n' "$file" "$key" >&2
        violations=$((violations + 1))
        continue
        ;;
    esac
    if in_list "$key" "$saw_keys"; then
      printf '    %s: duplicate field %s\n' "$file" "$key" >&2
      violations=$((violations + 1))
      continue
    fi
    saw_keys="$saw_keys $key"
    if ! in_list "$key" "$ALLOWED_KEYS"; then
      printf '    %s: unknown field %s\n' "$file" "$key" >&2
      violations=$((violations + 1))
      continue
    fi
    case "$key" in
      style) style="$val" ;;
      fidelity) fidelity="$val" ;;
      framing) framing="$val" ;;
      output_contract) output_contract="$val" ;;
    esac
  done <<< "$fm"

  if [ -z "$style" ]; then
    printf '    %s: missing required field style\n' "$file" >&2
    violations=$((violations + 1))
  elif ! in_list "$style" "$STYLE_ENUM"; then
    printf '    %s: style %s is not a member of the closed enum (%s)\n' \
      "$file" "$style" "$STYLE_ENUM" >&2
    violations=$((violations + 1))
  fi

  if [ -z "$fidelity" ]; then
    printf '    %s: missing required field fidelity\n' "$file" >&2
    violations=$((violations + 1))
  elif ! in_list "$fidelity" "$FIDELITY_ENUM"; then
    printf '    %s: fidelity %s is not a member of the closed enum (%s)\n' \
      "$file" "$fidelity" "$FIDELITY_ENUM" >&2
    violations=$((violations + 1))
  fi

  if [ -z "$framing" ]; then
    printf '    %s: missing required field framing\n' "$file" >&2
    violations=$((violations + 1))
  fi

  if [ -z "$output_contract" ]; then
    printf '    %s: missing required field output_contract\n' "$file" >&2
    violations=$((violations + 1))
  fi

  [ "$violations" -eq 0 ]
}

run_self_test() {
  local tmp
  tmp="$(mktemp -d)" || { echo 'mktemp -d failed' >&2; return 1; }
  SELF_TEST_TMP="$tmp"
  trap '[ -z "$SELF_TEST_TMP" ] || rm -rf "$SELF_TEST_TMP"' RETURN EXIT INT TERM

  # Good fixtures: one per style-enum member, all fields present.
  cat > "$tmp/good-socratic.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: Resolve open plan questions before implementation starts.
output_contract: Emits RESOLVED_TERM and ADR_CANDIDATE signals; no artifact.
---
EOF
  cat > "$tmp/good-adversarial.md" <<'EOF'
---
style: adversarial
fidelity: high
framing: Attack the plan until it survives, for a shareable build.
output_contract: Emits HANDOFF_SUGGESTION signals routed to the caller.
---
EOF
  cat > "$tmp/good-rapid.md" <<'EOF'
---
style: rapid
fidelity: low
framing: Fast intake clarification for a vague captured goal.
output_contract: Emits RESOLVED_TERM signals only.
---
EOF

  # Valid YAML spellings of the same values: quoted, trailing space, extra
  # leading space, trailing comment. All must normalize and be ACCEPTED.
  cat > "$tmp/good-normalized-values.md" <<'EOF'
---
style: "socratic"
fidelity:  mid
framing: 'Quoted, padded and commented values are still valid YAML scalars.'
output_contract: Emits RESOLVED_TERM signals only. # trailing comment
---
EOF
  # Written with printf, not a heredoc: the trailing whitespace IS the fixture,
  # and a heredoc's trailing spaces do not survive routine editor hygiene.
  printf '%s\n' \
    '---' \
    'style: socratic ' \
    'fidelity: mid   ' \
    'framing: Trailing whitespace is not part of a scalar value.  ' \
    'output_contract: Emits RESOLVED_TERM signals only. ' \
    '---' > "$tmp/good-trailing-space.md"

  # Bad fixtures: one violation each, isolated so each required field and
  # each rejection rule is exercised independently.
  cat > "$tmp/bad-missing-style.md" <<'EOF'
---
fidelity: mid
framing: No style field at all.
output_contract: Emits nothing in particular.
---
EOF
  cat > "$tmp/bad-unknown-style.md" <<'EOF'
---
style: interrogation
fidelity: mid
framing: Style names a value outside the closed enum.
output_contract: Emits nothing in particular.
---
EOF
  cat > "$tmp/bad-missing-fidelity.md" <<'EOF'
---
style: socratic
framing: No fidelity field at all.
output_contract: Emits nothing in particular.
---
EOF
  cat > "$tmp/bad-unknown-fidelity.md" <<'EOF'
---
style: socratic
fidelity: extreme
framing: Fidelity names a value outside the closed enum.
output_contract: Emits nothing in particular.
---
EOF
  cat > "$tmp/bad-missing-framing.md" <<'EOF'
---
style: socratic
fidelity: mid
output_contract: Emits nothing in particular.
---
EOF
  cat > "$tmp/bad-missing-output-contract.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: No output_contract field at all.
---
EOF
  cat > "$tmp/bad-stop-rule-override.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: Declares a per-preset stop rule escape hatch.
output_contract: Emits nothing in particular.
stop_rule_override: stop-after-one-question
---
EOF
  cat > "$tmp/bad-purpose-field.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: Declares a purpose enum field that duplicates framing.
output_contract: Emits nothing in particular.
purpose: learning
---
EOF
  cat > "$tmp/bad-no-frontmatter.md" <<'EOF'
# Not a preset

This file has no frontmatter block at all.
EOF

  # Fail-open regressions: each of these was ACCEPTED by the line-anchored
  # parser that silently dropped any frontmatter line it did not recognize.
  cat > "$tmp/bad-indented-override.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: Hides a forbidden field behind one leading space.
output_contract: Emits nothing in particular.
 stop_rule_override: hatch
---
EOF
  printf '%s\n' \
    '---' \
    'style: socratic' \
    'fidelity: mid' \
    'framing: Hides a forbidden field behind a leading tab.' \
    'output_contract: Emits nothing in particular.' \
    '	stop_rule_override: hatch' \
    '---' > "$tmp/bad-tabbed-override.md"
  cat > "$tmp/bad-hyphen-key.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: Spells the forbidden field with hyphens instead of underscores.
output_contract: Emits nothing in particular.
stop-rule-override: hatch
---
EOF
  cat > "$tmp/bad-block-scalar.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: |
  Free content hidden in a block scalar.
  stop_rule_override: sneaky
output_contract: Emits nothing in particular.
---
EOF
  cat > "$tmp/bad-unterminated.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: The frontmatter block is never closed.
output_contract: Emits nothing in particular.

# unterminated

Body prose that a parser treating EOF as an implicit close would misread.
EOF
  cat > "$tmp/bad-quoted-empty-framing.md" <<'EOF'
---
style: socratic
fidelity: mid
framing: ""
output_contract: Emits nothing in particular.
---
EOF
  printf '%s\n' \
    '---' \
    'style: socratic' \
    'fidelity: mid' \
    'framing:    ' \
    'output_contract: Emits nothing in particular.' \
    '---' > "$tmp/bad-blank-framing.md"
  cat > "$tmp/bad-duplicate-style.md" <<'EOF'
---
style: interrogation
style: socratic
fidelity: mid
framing: Declares style twice, so last-wins would launder an invalid value.
output_contract: Emits nothing in particular.
---
EOF

  local good_files="good-socratic good-adversarial good-rapid \
good-normalized-values good-trailing-space"
  local bad_files="bad-missing-style bad-unknown-style bad-missing-fidelity \
bad-unknown-fidelity bad-missing-framing bad-missing-output-contract \
bad-stop-rule-override bad-purpose-field bad-no-frontmatter \
bad-indented-override bad-tabbed-override bad-hyphen-key bad-block-scalar \
bad-unterminated bad-quoted-empty-framing bad-blank-framing \
bad-duplicate-style"

  local mismatches=0 name

  for name in $good_files; do
    if ! validate_preset "$tmp/$name.md" 2>/dev/null; then
      printf 'self-test FAIL: %s expected to pass, was rejected\n' "$name" >&2
      validate_preset "$tmp/$name.md"
      mismatches=$((mismatches + 1))
    fi
  done

  for name in $bad_files; do
    if validate_preset "$tmp/$name.md" 2>/dev/null; then
      printf 'self-test FAIL: %s expected to be rejected, was accepted\n' "$name" >&2
      mismatches=$((mismatches + 1))
    fi
  done

  local total=0
  for name in $good_files $bad_files; do total=$((total + 1)); done

  if [ "$mismatches" -ne 0 ]; then
    printf 'self-test FAILED: %d/%d fixture(s) mismatched expectation\n' "$mismatches" "$total" >&2
    return 1
  fi

  printf 'self-test OK: %d fixture(s) matched expectation\n' "$total"
  return 0
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

if [ "$1" = "--self-test" ]; then
  run_self_test
  exit $?
fi

if [ "$1" = "--print-style-enum" ]; then
  printf '%s\n' $STYLE_ENUM
  exit 0
fi

if [ "$1" = "--print-fields" ]; then
  [ $# -eq 2 ] || { usage; exit 1; }
  [ -f "$2" ] || { printf '    %s: file not found\n' "$2" >&2; exit 1; }
  print_fields "$2"
  exit 0
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 0
fi

failed=0
for preset in "$@"; do
  if validate_preset "$preset"; then
    printf 'OK %s\n' "$preset"
  else
    printf 'FAIL %s\n' "$preset" >&2
    failed=$((failed + 1))
  fi
done

[ "$failed" -eq 0 ] || exit 1
exit 0
