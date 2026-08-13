---
description: Widen the field before narrowing it — the interview front door with the brainstorm preset.
---

# /brainstorm

Alias of the `interview` front door (`adapters/claude-code/skills/interview/SKILL.md`), invoked
with the fixed argument `preset: brainstorm`.

Invoke the `interview` skill, passing `preset: brainstorm` through unchanged.
The front door performs the resolution; this wrapper supplies only the name.

Any text the user passes after `/brainstorm` names the subject to be opened up —
a problem, a design question, a decision with no obvious options — never a
different preset name. To run another preset, use `/interview`.
