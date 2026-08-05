#!/usr/bin/env bash
# publish-gate.sh — pre-publication personal-data / leak scrub.
#
#   publish-gate.sh <repo>              scan <repo>; exit 0 clean, non-zero on any finding
#   publish-gate.sh --self-test <repo>  prove the detector on a planted fixture, THEN scan <repo>
#
# Contract: base-system-map ticket-09 (`publish-gate`). What gets published is
# not the working tree — it is every object a clone can reach. This scrub
# therefore has five legs:
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
# Detection classes ship base64-encoded, for the same reason
# core/evals/cases/purity/denylist.b64 does: stored as plain text, this script
# would be the only file in the tree matching its own patterns, and a
# self-exclusion carved out to compensate would be a permanent hole in the scan.
#
# Exemptions are explicit, committed, and never silent: see publish-gate.allow
# next to this script. Every applied exemption is printed; an allow entry that
# matches nothing fails the gate, so stale exemptions cannot accumulate.

set -uo pipefail

PATTERNS_B64='YWJzLWhvbWUtcGF0aAkoXnxbXls6YWxudW06XV8uLV0pL2hvbWUvW0EtWmEtejAtOS5fLV0rCmFicy11c2Vycy1wYXRoCShefFteWzphbG51bTpdXy4tXSkvVXNlcnMvW0EtWmEtejAtOS5fLV0rCmVtYWlsCVtBLVphLXowLTkuXyUrLV0rQFtBLVphLXowLTkuLV0rXC5bQS1aYS16XXsyLH0JQHVzZXJzXC5ub3JlcGx5XC5naXRodWJcLmNvbSQKc2VjcmV0CShBS0lBWzAtOUEtWl17MTZ9fGdoW3BvdXNyXV9bQS1aYS16MC05XXsyMCx9fHNrLVtBLVphLXowLTlfLV17MjAsfXx4b3hbYmFwcnNdLVtBLVphLXowLTktXXsxMCx9fC0tLS0tQkVHSU4gW0EtWiBdKlBSSVZBVEUgS0VZLS0tLS18KGFwaVtfLV0/a2V5fGFwaWtleXxzZWNyZXR8dG9rZW58cGFzc3dkfHBhc3N3b3JkKVsiJ10/W1s6c3BhY2U6XV0qWzo9XVtbOnNwYWNlOl1dKlsiJ10/W0EtWmEtejAtOS8rPV8tXXsyMCx9KQpzZXNzaW9uLWlkCVswLTlhLWZdezh9LVswLTlhLWZdezR9LVswLTlhLWZdezR9LVswLTlhLWZdezR9LVswLTlhLWZdezEyfQpzZGQtdGFzay1pZAkoXnxbXkEtWmEtejAtOV0pKHRhc2t8d3ApLVswLTldezJ9LVthLXowLTktXSsK'

# Self-test fixture: a tarball carrying one file with a planted absolute home
# path, a planted address, and two planted key-shaped strings; one file under a
# private path class; and the commit metadata to plant on the fixture commit.
FIXTURE_B64='H4sIAAAAAAAAA+3W3YubQBAAcJ/9K5bry92D31/JQaCBJhDa3h39gLQvYaJjso2u4q5p8t9XL6aUlCMUasr15gdi2B1dcdbJmJbWO7sRRUF7dqLA/vV8pDmB6/lh6Eaeq9mOHQSRxoL+H03TaqmgYkyLa7HC6um4c/PPlGnlqKDfNdoEh6H/ZP492z3Jv+O7nsbsfh/r4IXnH2q1LqqFgBxHDxkIhQmb8p2qK2Tjxzm9C8EceDYqDzHmYfA17iAvMzS52ELGE13Wy28Yq1GKoK4VyI1hD43uGiM93PfmlnUjbM2lKqo9a/dgAgr0ZZHsRxKl5IW4ZXY6SCEJlkYyjJeGHw5TA5wwMCJ7EEaROxgGNur/+g0+b6bV5kL2+i/w5/XfCSOf6v8lHPNfVnwLCg1RKDTz5K+uca7+2/5p/febH1T/L+FYibv8P1ZmwcWKQaV4CrGi+vpfM60MYWOqnepvjbP9n+ecfP+u2wzR938Br372Yu0+YF2Lxq4lZqmhUComcAWKb5HFIPFGjwuR8tWiKgrFRsxaFzla3VW1xMoyDwEWlKXedIxCNQdWTWgXZJZYyUL81jnCd7nY4L4JHL+djWf3H6f3b+7uosl8/P7h3USHknfTV01TOZ3NP33+MOlu2ewXzw/CaDCEZZxgOv/y9YrKFiGEEEIIIYQQQgghhBBCXqofpyK9aAAoAAA='

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
# installed a private denylist file.
personal_strings() {
  {
    git config --global user.name
    git config --global user.email
    basename "$HOME"
  } 2>/dev/null | sed '/^$/d' | grep -vE "$NOREPLY_RE" | awk 'length($0) >= 4' | sort -u
}

scan_file() { # leg path loc file
  local leg="$1" path="$2" loc="$3" file="$4"
  grep -Iq . "$file" 2>/dev/null || return 0   # binary or empty: nothing to read

  local class pat allow lineno text hits hit nl
  while IFS=$'\t' read -r class pat allow; do
    [ -n "${class:-}" ] || continue
    while IFS= read -r nl; do
      lineno="${nl%%:*}"
      text="${nl#*:}"
      if [ -n "${allow:-}" ]; then
        hits="$(printf '%s\n' "$text" | grep -oE "$pat" | grep -vE "$allow")"
      else
        hits="$(printf '%s\n' "$text" | grep -oE "$pat")"
      fi
      while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        emit "$leg" "$class" "$path" "$loc:$lineno" "$hit"
      done <<< "$hits"
    done < <(grep -nE "$pat" "$file" 2>/dev/null)
  done < "$WORK/patterns.tsv"

  if [ -s "$WORK/personal.txt" ]; then
    while IFS= read -r nl; do
      lineno="${nl%%:*}"
      emit "$leg" "personal-string" "$path" "$loc:$lineno" "${nl#*:}"
    done < <(grep -nFf "$WORK/personal.txt" "$file" 2>/dev/null)
  fi
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
    scan_file "history-meta" "-" "commit:${sha:0:12}" "$WORK/meta.txt"
  done < <(git -C "$repo" log --all --format='%H' 2>/dev/null)

  # -- leg: history-path -----------------------------------------------------
  while IFS= read -r p; do
    scan_path "history-path" "$p"
  done < <(git -C "$repo" log --all --name-only --format='' 2>/dev/null | sed '/^$/d' | sort -u)

  # -- leg: history-blob -----------------------------------------------------
  # Every blob reachable from every ref — the bytes a clone actually receives.
  git -C "$repo" rev-list --objects --all 2>/dev/null \
    | git -C "$repo" cat-file --batch-check='%(objectname) %(objecttype) %(rest)' 2>/dev/null \
    > "$WORK/objects.txt"
  : > "$WORK/seen.txt"
  while read -r sha type rest; do
    [ "$type" = "blob" ] || continue
    grep -qxF "$sha" "$WORK/seen.txt" && continue
    printf '%s\n' "$sha" >> "$WORK/seen.txt"
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

# publish-gate.allow: "<path><TAB><class><TAB><reason>", '#' comments.
# Applied only to the real-repo scan; the fixture never carries one.
apply_allow() { # repo
  local allow="$SCRIPT_DIR/publish-gate.allow"
  [ -r "$allow" ] || return 0

  local apath aclass reason kept dropped rc=0
  cp "$FINDINGS" "$WORK/remaining.txt"

  while IFS=$'\t' read -r apath aclass reason; do
    case "${apath:-}" in ''|'#'*) continue ;; esac
    dropped="$(awk -F'\t' -v p="$apath" -v c="$aclass" '$3==p && $2==c' "$WORK/remaining.txt")"
    if [ -z "$dropped" ]; then
      echo "error: stale exemption in publish-gate.allow — [$apath / $aclass] matches nothing" >&2
      rc=1
      continue
    fi
    printf 'exempt: %s / %s (%s) — %s finding(s)\n' \
      "$apath" "$aclass" "$reason" "$(printf '%s\n' "$dropped" | wc -l)" >&2
    kept="$(awk -F'\t' -v p="$apath" -v c="$aclass" '!($3==p && $2==c)' "$WORK/remaining.txt")"
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
  awk -F'\t' '{printf "  [%s] %s  %s\n      %s\n", $2, $1, $4, $5}' "$FINDINGS" >&2
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

  git -C "$dir" init -q -b main
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
    "tree:email"
    "tree:secret"
    "tree-path:private-path"
    "history-meta:email"
    "history-meta:sdd-task-id"
    "history-meta:session-id"
    "history-path:private-path"
    "history-blob:abs-home-path"
    "history-blob:secret"
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
  personal_strings > "$WORK/personal.txt"

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
