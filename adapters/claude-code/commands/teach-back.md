---
description: Teach-back on settled material — the interview front door with the teach-back preset.
---

# /teach-back

Alias of the `interview` front door (`adapters/claude-code/skills/interview/SKILL.md`), invoked
with the fixed argument `preset: teach-back`.

Invoke the `interview` skill, passing `preset: teach-back` through unchanged.
The front door performs the resolution; this wrapper supplies only the name.

Any text the user passes after `/teach-back` names the material the user will
explain back — a spec, a doc, a decision record — never a different preset name.
To run another preset, use `/interview`.
