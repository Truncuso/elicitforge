---
description: Bare grill session — the interview front door with no preset.
---

# /grill

Alias of the `interview` front door (`adapters/claude-code/skills/interview/SKILL.md`), invoked
with **no** `preset:` argument.

Invoke the `interview` skill and run a bare grill session: the default socratic
loop, no preset question set loaded, no preset resolution performed. Because no
preset name is supplied, `${CLAUDE_PLUGIN_ROOT}/presets/<name>.md` is never
read and the unknown-preset halt never applies.

Any text the user passes after `/grill` is the subject under grilling — a plan,
a spec, an idea, a diff — not a preset name. To run a named preset, use
`/interview` instead.
