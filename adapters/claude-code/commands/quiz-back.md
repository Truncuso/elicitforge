---
description: Retrieval-practice quiz on settled material — the interview front door with the quiz-back preset.
---

# /quiz-back

Alias of the `interview` front door (`adapters/claude-code/skills/interview/SKILL.md`), invoked
with the fixed argument `preset: quiz-back`.

Invoke the `interview` skill, passing `preset: quiz-back` through unchanged.
The front door performs the resolution; this wrapper supplies only the name.

Any text the user passes after `/quiz-back` names the settled material to be
quizzed on — a spec, a doc, a decision record — never a different preset name.
To run another preset, use `/interview`.
