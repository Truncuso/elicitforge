---
name: interview
description: >-
  One-question-at-a-time interview engine that pressure-tests plans, specs, and
  ideas and emits structured signals (RESOLVED_TERM, ADR_CANDIDATE,
  HANDOFF_SUGGESTION). Use when the user says "grill me", "interview me",
  "stress-test this plan", "pressure-test this spec", "clarify what I actually
  want", "ask me questions about this", or when an orchestrator needs an
  interactive clarification/elicitation loop before drafting a spec, capturing
  an idea, or hardening a work package. Accepts an optional `preset: <name>`
  argument selecting a preset question set. SKIP for lightweight one-off
  clarification — use AskUserQuestion instead.
---

# interview

Public front door for the elicitforge interview engine on Claude Code. This
file is an adapter: it resolves the caller's `preset:` argument onto a preset
file and hands control to the engine. The engine's conduct rules and the
signals contract live in `core/`, which is harness-agnostic and knows nothing
about this address.

## Argument

```
preset: <name>
```

`<name>` is a bare preset name — no path, no `.md` extension, no directory
prefix. Example: `preset: spec-grill`.

The argument is optional. Invoked with no `preset:`, this skill runs a **bare
grill session**: the default socratic loop, no preset question set loaded.

## Resolution

A `preset: <name>` argument resolves to exactly this address:

```
${CLAUDE_PLUGIN_ROOT}/presets/<name>.md
```

That literal — `${CLAUDE_PLUGIN_ROOT}`, then `/presets/`, then the bare name,
then the `.md` extension — is the only address this front door reads. Do not
prefix the name with `core/`, do not drop the `.md` extension, and do not
substitute a repo-relative path: the plugin is installed outside the source
tree and only `${CLAUDE_PLUGIN_ROOT}` is a valid anchor at runtime.

`presets/` is a real, committed directory at the plugin root, vendored from the
harness-agnostic `core/presets/` in the source repo. It is a generated
artifact: `core/` is the single source of truth and the only place a preset is
edited, and an eval case (`evals/cases/vendored-presets-sync.sh`) fails the
moment the two copies differ.

It is vendored rather than symlinked because the plugin root is installed on
its own — the host materializes only `adapters/claude-code/`, so `core/` is
never present at runtime and any path escaping this directory would dangle.
Nothing under this plugin root resolves outside it.

## Unknown or missing preset

If `${CLAUDE_PLUGIN_ROOT}/presets/<name>.md` does not exist:

1. **Halt.** Do not start the interview.
2. Enumerate the available presets from the resolved `presets/` directory —
   list the actual `*.md` basenames found there, not a hardcoded list.
3. Report the unknown name and the enumerated list to the caller, and wait for
   a corrected `preset:` argument.

Never silently fall back to a default preset, to a bare grill session, or to a
name that merely resembles the one requested. A caller who asked for a specific
preset and got a different loop has no way to notice.

The same halt applies when the resolved `presets/` directory itself is missing
or unreadable — report that the preset directory could not be resolved rather
than proceeding without it.

## Running

1. Resolve the preset (or note that none was requested).
2. Read the preset's frontmatter — `style`, `fidelity`, `framing`,
   `output_contract` — and the engine's conduct rules from `core/`.
3. Run the loop: one question at a time, each with a recommended answer and a
   confidence number, stopping on predictive confidence.
4. Emit the signals the preset's `output_contract` declares. The engine writes
   no spec text and no decision record — the caller owns those.

## Commands

| Command | Behavior |
|---|---|
| `/grill` | This front door with **no** preset argument — a bare grill session. |
| `/interview` | This front door with a caller-supplied `preset: <name>`. |
