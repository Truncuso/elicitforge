#!/usr/bin/env bash
# publish-gate.sh — pre-publication personal-data / leak scrub.
#
#   publish-gate.sh <repo>              scan <repo>; exit 0 clean, non-zero on any finding
#   publish-gate.sh --self-test <repo>  prove the detector on a planted fixture, THEN scan <repo>
#
# What gets published is not the working tree — it is every object a clone can
# reach. This scrub therefore has five object legs:
#
#   tree          content of tracked + untracked-but-not-ignored files
#   tree-path     those files' PATHS, against the private path-class denylist
#   history-meta  author/committer name+email, subject and body of every commit
#                 reachable from every ref (`--all`)
#   history-path  every path ever committed on any ref
#   history-blob  the content of every blob reachable from any ref
#
# A tree-only scan is not sufficient: history is effectively immutable once a
# clone exists, and rewriting it is only cheap BEFORE the first push.
#
# A sixth, non-object leg (`config`) checks the identity this repo would author
# future commits with.
#
# Nothing is skipped silently. A file `grep -I` classifies as binary is not
# passed over — its printable runs are extracted and scanned under a `-binary`
# leg suffix — and a personal-string set that cannot be derived is a hard error
# rather than a quietly-omitted leg: a scan that did not run must never report
# CLEAN.
#
# Detection classes ship base64-encoded, for the same reason
# core/evals/cases/purity/denylist.b64 does: stored as plain text, this script
# would be the only file in the tree matching its own patterns, and a
# self-exclusion carved out to compensate would be a permanent hole in the scan.
#
# Exemptions are explicit, committed, and never silent: see publish-gate.allow
# next to this script. Every applied exemption is printed; an allow entry that
# matches nothing fails the gate, so stale exemptions cannot accumulate.

set -uo pipefail

PATTERNS_B64='YWJzLWhvbWUtcGF0aAkoXnxbXls6YWxudW06XV8uLV0pL2hvbWUvW0EtWmEtejAtOS5fLV0rCS0JLQphYnMtdXNlcnMtcGF0aAkoXnxbXls6YWxudW06XV8uLV0pL1VzZXJzL1tBLVphLXowLTkuXy1dKwktCS0KZW1haWwJW0EtWmEtejAtOS5fJSstXStAW0EtWmEtejAtOS4tXStcLltBLVphLXpdezIsfQlAdXNlcnNcLm5vcmVwbHlcLmdpdGh1YlwuY29tJAktCnNlY3JldAkoQUtJQVswLTlBLVpdezE2fXxnaFtwb3Vzcl1fW0EtWmEtejAtOV17MjAsfXxzay1bQS1aYS16MC05Xy1dezIwLH18eG94W2JhcHJzXS1bQS1aYS16MC05LV17MTAsfXwtLS0tLUJFR0lOIFtBLVogXSpQUklWQVRFIEtFWS0tLS0tKQktCS0Kc2VjcmV0CShhcGlbXy1dP2tleXxhcGlrZXl8c2VjcmV0fHRva2VufHBhc3N3ZHxwYXNzd29yZClbIiddP1tbOnNwYWNlOl1dKls6PV1bWzpzcGFjZTpdXSpbIiddP1tBLVphLXowLTkvKz1fLV17MjAsfQktCWkKc2Vzc2lvbi1pZAlbMC05YS1mXXs4fS1bMC05YS1mXXs0fS1bMC05YS1mXXs0fS1bMC05YS1mXXs0fS1bMC05YS1mXXsxMn0JLQlpCnNkZC10YXNrLWlkCShefFteQS1aYS16MC05XSkoW1R0XWFza3xbV3ddW1BwXXxbVHRdaWNrZXQpLVswLTldezEsM30oW14wLTldfCQpCS0JLQo='

# Self-test fixture: a tarball of planted leaks plus the commit metadata to
# plant on the fixture commit. The plants are deliberately NOT written to the
# shape of the regexes below — a fixture fitted to its own detector proves only
# that a string can be echoed back. They are the shapes real leaks take:
# `API_KEY = "..."` and `Passwd:` in mixed case, a one-digit task id with no
# trailing slug, a capitalized `WP-`, a `ticket-`, a macOS `/Users/` path, and a
# key buried in a binary file that `grep -I` refuses to read. The personal-string
# plant cannot be shipped in the tarball at all (the strings are machine-derived)
# and is written into the fixture at build time by build_fixture.
FIXTURE_B64='H4sIAJw2dGoC/+2YW0/bMBSAs+2tv8LaE0ikuTZtmSoNSrmMWxnswl6QE582obGd2U5Ledk/3+YEhgZ7QJNGYZs/KY1rW7GU9js+x4wrkI4EVRZNSqwHwdVEYVjfNXfvbtC+Gbvq99xWFFjItRZAKRUWennr/6SfcwYoUyhjiiMn5RQcAtNSgnBmXEz0F8oRZgSJkiGKJ9BsDDM2RpjgZs6nkOMEXsMFpkUOTS7GaJYCQyoFxLJxqvI5ymjBhUKxADyRzcbacOdsd3CKeujlJ9qdntLNub6i5ON7DzYG8/3LI+/gPAkPT9bTU7rfe9kYYilnZBX1uRCQKHubCwn2OlYKxNw+VlivbId+Ay7qdba2z4ZrJ71xWpy5nh+Erajd6eI4ITAap9n52np/Y7C5tb3zpmEZLFb7T3HC5aP57/3U/uG/5xr/F8EhQxjt46Q2NsGJ/sy17VLHA+S801FA3oSDvSwWWMydfjVL1oGhaRz6yyE8kY7gmFD8YAnAvf4H0V3/o9A3/i+C4zQrCiCV7rPCDtGSBEAfhrbnoxEXdVQY8TznM7sslpuN9ZwnEz2d6y0+0y1ld1HJVJbXM2k2FlhlerCOISY6PH0K/UtJh8GFsj+XWOiU6s9Hgfv8d8Pgjv++G5r9fyHotB8Ewzmq/ghMJ/YriMEUBCrKOM9kCsRI/C+jaytQ18lcnLFH2v9bv+z/UWj8XwRfBnublvXsedWOyywn+nXQwrKq8vlS0+20o1YY+J57VULv7u0fHA6P3h6fWNa3r7fPC4DGQAgQp8Aq1c98YfR68lBQ+KHXuM9/P/Jv+6/19yLj/0Lif6lSLs4YptDbgCmqSv7GdSdQnOU9bXez0vvmkI+BasgyPodE9UaA1VJVOCyv1jl/XQZcHfjp58SczHv9nEuQN+XCCpJlAUIC0Z11ofEK6XFZVQ0u9mI/CYgdQmtkR27bszt+N7BxGLeSiLShM+qadMRgMBgMBoPBYDAYDAaD4bf4Du/4wpEAKAAA'

# Path classes that must never be published, whatever their content.
PRIVATE_PATH_RE='(^|/)(plans|tmp)/|(^|/)\.memory/|(^|/)docs/handoffs/|\.conv\.md$'

# The only address domain permitted in commit metadata and in the tree.
NOREPLY_RE='^[A-Za-z0-9._%+-]+@users\.noreply\.github\.com$'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

usage() {
  cat >&2 <<'EOF'
usage:
  publish-gate.sh <repo>              scan <repo>; exit 0 clean, non-zero on any finding
  publish-gate.sh --self-test <repo>  prove the detector on a planted fixture, then scan <repo>
EOF
}

# ---------------------------------------------------------------- findings ---

FINDINGS=""      # file: LEG \t CLASS \t PATH \t LOC \t EVIDENCE

emit() { # leg class path loc evidence
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$(printf '%s' "$5" | cut -c1-160)" >> "$FINDINGS"
}

# ---------------------------------------------------------------- scanning ---

# Fixed strings that identify the operator of this machine. Derived, not
# configured, so the check cannot silently no-op on a machine that never
# installed a private denylist file. Deriving NOTHING is a hard error at the
# call site (see main) — on a machine with no global git identity this used to
# reduce to an empty grep pattern file and the leg vanished from a run that
# still printed CLEAN.
personal_strings() {
  {
    git config --global user.name
    git config --global user.email
    basename "$HOME"
  } 2>/dev/null | sed '/^$/d' | grep -vE "$NOREPLY_RE" | awk 'length($0) >= 4' | sort -u
}

scan_file() { # leg path loc file
  local leg="$1" path="$2" loc="$3" file="$4"
  local target="$file"

  # `grep -I` classifies a file with any NUL byte as binary and reports NOTHING
  # for it — a leak inside a compiled artifact, an archive, or a stray core dump
  # was previously invisible on every leg. Scan the printable runs instead, under
  # a distinct `-binary` leg so the weaker read is visible in the report rather
  # than passed off as a normal text scan. Line numbers on that leg index the
  # extracted runs, not the bytes.
  if ! grep -Iq '' "$file" 2>/dev/null; then
    [ -s "$file" ] || return 0                 # genuinely empty: nothing to read
    if command -v strings >/dev/null 2>&1; then
      strings -n 8 "$file" > "$WORK/strings.txt" 2>/dev/null || : > "$WORK/strings.txt"
    else
      : > "$WORK/strings.txt"
    fi
    if [ ! -s "$WORK/strings.txt" ]; then
      printf 'skipped-binary: %s (%s) — no printable runs could be extracted\n' \
        "$path" "$loc" >&2
      return 0
    fi
    leg="$leg-binary"
    target="$WORK/strings.txt"
  fi

  # patterns.tsv columns: class, regex, allow-regex, flags — NEVER empty, '-'
  # means "none". Tab is IFS whitespace, so `read` collapses a run of tabs into
  # one delimiter and an empty column shifts every later column left by one;
  # that silently reverted the case-insensitive rows to case-sensitive on the
  # first write of this loop.
  local class pat allow flags lineno text hits hit nl
  local -a gopts
  while IFS=$'\t' read -r class pat allow flags; do
    [ -n "${class:-}" ] || continue
    [ "${allow:--}" = "-" ] && allow=""
    # Per-row case sensitivity. Only rows whose KEYWORD is prose match -i;
    # literal key shapes (AKIA…, gh?_…, the PEM header) stay exact, because for
    # those the case IS the signal and -i would widen them into noise.
    gopts=(-E)
    case "${flags:-}" in *i*) gopts+=(-i) ;; esac
    while IFS= read -r nl; do
      lineno="${nl%%:*}"
      text="${nl#*:}"
      if [ -n "${allow:-}" ]; then
        hits="$(printf '%s\n' "$text" | grep -o "${gopts[@]}" -- "$pat" | grep -vE "$allow")"
      else
        hits="$(printf '%s\n' "$text" | grep -o "${gopts[@]}" -- "$pat")"
      fi
      while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        emit "$leg" "$class" "$path" "$loc:$lineno" "$hit"
      done <<< "$hits"
    done < <(grep -n "${gopts[@]}" -- "$pat" "$target" 2>/dev/null)
  done < "$WORK/patterns.tsv"

  # personal.txt is guaranteed non-empty by main — an empty set is a hard error
  # there, never a skipped leg here.
  while IFS= read -r nl; do
    lineno="${nl%%:*}"
    emit "$leg" "personal-string" "$path" "$loc:$lineno" "${nl#*:}"
  done < <(grep -nFf "$WORK/personal.txt" "$target" 2>/dev/null)
}

scan_path() { # leg path
  case "$2" in '') return 0 ;; esac
  printf '%s\n' "$2" | grep -qE "$PRIVATE_PATH_RE" \
    && emit "$1" "private-path" "$2" "path" "$2"
  return 0
}

scan_repo() { # repo  -> appends to $FINDINGS
  local repo="$1" p sha type rest loc

  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "error: not a git repository: $repo" >&2
    return 2
  }

  # -- leg: tree + tree-path -------------------------------------------------
  while IFS= read -r -d '' p; do
    scan_path "tree-path" "$p"
    [ -f "$repo/$p" ] && scan_file "tree" "$p" "$p" "$repo/$p"
  done < <(git -C "$repo" ls-files -co --exclude-standard -z)

  # -- leg: history-meta -----------------------------------------------------
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    git -C "$repo" log -1 --format='%an%n%ae%n%cn%n%ce%n%s%n%b' "$sha" > "$WORK/meta.txt" </dev/null
    # The commit IS the object this finding lives in — naming it as the path
    # keeps an exemption pinned to one immutable commit instead of to every
    # commit message the repo will ever have.
    scan_file "history-meta" "commit:${sha:0:12}" "commit:${sha:0:12}" "$WORK/meta.txt"
  done < <(git -C "$repo" log --all --format='%H' 2>/dev/null)

  # -- leg: history-path -----------------------------------------------------
  # --diff-merges=first-parent: a merge commit shows NO diff by default, so a
  # path introduced only by a merge (a conflict resolution, an -X ours/theirs
  # take) never appeared in this leg's output while being perfectly reachable
  # in the published tree.
  while IFS= read -r p; do
    scan_path "history-path" "$p"
  done < <(git -C "$repo" log --all --name-only --format='' --diff-merges=first-parent 2>/dev/null \
             | sed '/^$/d' | sort -u)

  # -- leg: history-blob -----------------------------------------------------
  # Every blob reachable from every ref — the bytes a clone actually receives.
  git -C "$repo" rev-list --objects --all 2>/dev/null \
    | git -C "$repo" cat-file --batch-check='%(objectname) %(objecttype) %(rest)' 2>/dev/null \
    > "$WORK/objects.txt"
  local -A seen=()
  while read -r sha type rest; do
    [ "$type" = "blob" ] || continue
    [ -n "${seen[$sha]:-}" ] && continue
    seen[$sha]=1
    git -C "$repo" cat-file blob "$sha" > "$WORK/blob.bin" 2>/dev/null </dev/null || continue
    scan_file "history-blob" "${rest:--}" "blob:${sha:0:12}" "$WORK/blob.bin"
  done < "$WORK/objects.txt"

  # -- leg: config -----------------------------------------------------------
  local cfg
  cfg="$(git -C "$repo" config user.email 2>/dev/null)"
  if [ -z "$cfg" ]; then
    emit "config" "config-email" "-" "git config user.email" "(unset — inherits a global identity)"
  elif ! printf '%s' "$cfg" | grep -qE "$NOREPLY_RE"; then
    emit "config" "config-email" "-" "git config user.email" "$cfg"
  fi
}

# --------------------------------------------------------------- exemptions ---

# publish-gate.allow: "<path><TAB><class><TAB><loc><TAB><reason>", '#' comments.
# <loc> is `*` for any location, or a prefix of the finding's location — so an
# exemption for content frozen in an already-published object (a commit message,
# a v1.0.0 blob) can be pinned to that object alone and does NOT excuse the same
# leak reappearing in the working tree.
# Applied only to the real-repo scan; the fixture never carries one.
apply_allow() { # repo
  local allow="$SCRIPT_DIR/publish-gate.allow"
  [ -r "$allow" ] || return 0

  local apath aclass aloc reason kept dropped rc=0
  cp "$FINDINGS" "$WORK/remaining.txt"

  while IFS=$'\t' read -r apath aclass aloc reason; do
    case "${apath:-}" in ''|'#'*) continue ;; esac
    [ -n "${aloc:-}" ] || aloc='*'
    dropped="$(awk -F'\t' -v p="$apath" -v c="$aclass" -v l="$aloc" \
      '$3==p && $2==c && (l=="*" || index($4,l)==1)' "$WORK/remaining.txt")"
    if [ -z "$dropped" ]; then
      echo "error: stale exemption in publish-gate.allow — [$apath / $aclass @ $aloc] matches nothing" >&2
      rc=1
      continue
    fi
    printf 'exempt: %s / %s @ %s (%s) — %s finding(s)\n' \
      "$apath" "$aclass" "$aloc" "$reason" "$(printf '%s\n' "$dropped" | wc -l)" >&2
    kept="$(awk -F'\t' -v p="$apath" -v c="$aclass" -v l="$aloc" \
      '!($3==p && $2==c && (l=="*" || index($4,l)==1))' "$WORK/remaining.txt")"
    printf '%s\n' "$kept" | sed '/^$/d' > "$WORK/remaining.txt"
  done < "$allow"

  cp "$WORK/remaining.txt" "$FINDINGS"
  return "$rc"
}

# ---------------------------------------------------------------- reporting ---

report() { # label
  local n
  n="$(sed '/^$/d' "$FINDINGS" | wc -l)"
  if [ "$n" -eq 0 ]; then
    printf 'publish-gate: %s CLEAN\n' "$1"
    return 0
  fi
  printf 'publish-gate: %s — %d finding(s)\n' "$1" "$n" >&2
  # Path AND location: an exemption is keyed on the path, so a report that
  # only shows the location cannot be acted on without re-deriving it.
  awk -F'\t' '{printf "  [%s] %s  %s  (%s)\n      %s\n", $2, $1, $3, $4, $5}' "$FINDINGS" >&2
  return 1
}

# ---------------------------------------------------------------- self-test ---

build_fixture() { # dir
  local dir="$1"
  mkdir -p "$dir"
  printf '%s' "$FIXTURE_B64" | base64 -d | tar -C "$dir" -xzf -

  local an ae subj body
  an="$(sed -n 's/^author_name=//p' "$dir/meta")"
  ae="$(sed -n 's/^author_email=//p' "$dir/meta")"
  subj="$(sed -n 's/^subject=//p' "$dir/meta")"
  body="$(sed -n 's/^body=//p' "$dir/meta")"
  rm -f "$dir/meta"

  # The personal-string plant cannot ship in the tarball: the strings are
  # derived from THIS machine. Plant them here so the leg is exercised on the
  # same set the real scan will use.
  mkdir -p "$dir/notes"
  {
    echo "handover notes — reachable contacts for this build:"
    sed 's/^/  owner: /' "$WORK/personal.txt"
  } > "$dir/notes/owner.txt"

  git -C "$dir" init -q -b main
  # An identity outside the noreply domain: the `config` leg's whole job is to
  # catch a repo that would author its next commit with a personal address.
  git -C "$dir" config user.name "$an"
  git -C "$dir" config user.email "$ae"
  git -C "$dir" add -A
  git -C "$dir" \
    -c "user.name=$an" -c "user.email=$ae" \
    -c commit.gpgsign=false \
    commit -q --no-verify -m "$subj" -m "$body"
}

self_test() { # repo
  local fixture="$WORK/fixture" rc=0 leg class

  echo "publish-gate: self-test — planting a fixture and asserting each leg fires"
  build_fixture "$fixture" || { echo "error: could not build the self-test fixture" >&2; return 1; }

  : > "$FINDINGS"
  scan_repo "$fixture"

  # The negative case must be CAUGHT — per leg and per class, not merely
  # "something was reported". A gate that fires on one class and is blind to
  # the other four would pass a weaker assertion.
  local expected=(
    "tree:abs-home-path"
    "tree:abs-users-path"
    "tree:email"
    "tree:secret"
    "tree:sdd-task-id"
    "tree:personal-string"
    "tree-path:private-path"
    "tree-binary:secret"
    "history-meta:email"
    "history-meta:sdd-task-id"
    "history-meta:session-id"
    "history-path:private-path"
    "history-blob:abs-home-path"
    "history-blob:secret"
    "history-blob-binary:secret"
    "config:config-email"
  )
  local want
  for want in "${expected[@]}"; do
    leg="${want%%:*}"; class="${want#*:}"
    if awk -F'\t' -v l="$leg" -v c="$class" '$1==l && $2==c {found=1} END{exit !found}' "$FINDINGS"; then
      printf '  PASS caught %-14s on leg %s\n' "$class" "$leg"
    else
      printf '  FAIL missed %-14s on leg %s — the detector does not detect what it claims\n' \
        "$class" "$leg" >&2
      rc=1
    fi
  done

  if [ "$rc" -ne 0 ]; then
    echo "publish-gate: self-test FAILED — a clean exit on the real repo would be meaningless" >&2
    return 1
  fi
  echo "publish-gate: self-test OK — the detector flags the planted fixture"
  return 0
}

# --------------------------------------------------------------------- main ---

main() {
  local mode="scan" repo=""
  case "${1:-}" in
    --self-test) mode="self-test"; repo="${2:-}" ;;
    -h|--help)   usage; return 0 ;;
    "")          usage; return 2 ;;
    -*)          echo "error: unknown option: $1" >&2; usage; return 2 ;;
    *)           repo="$1" ;;
  esac
  [ -n "$repo" ] || { usage; return 2; }
  [ -d "$repo" ] || { echo "error: not a directory: $repo" >&2; return 2; }
  repo="$(cd "$repo" && pwd)"

  WORK="$(mktemp -d)"
  FINDINGS="$WORK/findings.tsv"
  printf '%s' "$PATTERNS_B64" | base64 -d > "$WORK/patterns.tsv"
  [ -s "$WORK/patterns.tsv" ] || { echo "error: pattern set decoded empty" >&2; return 2; }
  # Enforced, not merely documented: a row with an empty column reads back with
  # its later columns shifted, which downgrades a detector without failing.
  awk -F'\t' 'NF!=4 || $1=="" || $2=="" || $3=="" || $4=="" {exit 1}' "$WORK/patterns.tsv" \
    || { echo "error: every patterns.tsv row must be 4 non-empty tab-separated columns ('-' = none)" >&2; return 2; }
  personal_strings > "$WORK/personal.txt"
  if [ ! -s "$WORK/personal.txt" ]; then
    cat >&2 <<'EOF'
error: no personal strings could be derived — the personal-string leg cannot run.
  Sources: `git config --global user.name`, `git config --global user.email`,
  and the basename of $HOME (each must be at least 4 characters and outside the
  noreply domain).
  This is fatal, not skippable: a scan that silently drops a leg would report a
  repository CLEAN on evidence it never looked at. Set a global git identity, or
  run the gate from an account whose $HOME basename identifies it.
EOF
    return 2
  fi

  if [ "$mode" = "self-test" ]; then
    self_test "$repo" || return 1
  fi

  : > "$FINDINGS"
  scan_repo "$repo" || return 2
  local allow_rc=0
  apply_allow "$repo" || allow_rc=1
  report "$repo" || return 1
  [ "$allow_rc" -eq 0 ] || return 1
  return 0
}

main "$@"
