---
description: Interview front door with a caller-supplied preset.
argument-hint: "preset: <name>"
---

# /interview

Alias of the `interview` front door (`adapters/claude-code/skills/interview/SKILL.md`), invoked
with a caller-supplied preset.

Invoke the `interview` skill, passing the `preset: <name>` argument through
unchanged. The front door resolves it to the literal address
`${CLAUDE_PLUGIN_ROOT}/presets/<name>.md` — bare name, `.md` extension, no
`core/` prefix.

If the caller supplies no preset name, ask for one rather than guessing; a bare
grill session is `/grill`. If the named preset does not resolve, the front door
halts and lists the presets it found — do not substitute a default.
