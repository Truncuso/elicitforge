---
style: teachback
fidelity: mid
framing: Have the user explain settled material back in their own words — health-literacy teach-back, which never tests and never scores the learner. Every divergence between the explanation and the material is one gap-register entry, reflected back as something the explanation failed to carry and then re-explained, never as a mark against the person.
output_contract: Emits RESOLVED_TERM (with optional RELATED) when the user's own wording settles a term the material left fuzzy, ADR_CANDIDATE with its required WHY line when an explanation exposes an undocumented decision passing the three-condition gate (hard-to-reverse, surprising-without-context, real-trade-off), and HANDOFF_SUGGESTION with its required QUESTION line for every register entry re-explaining cannot close — research or expert when the material itself is missing, deferred when the gap is parked. No score and no verdict on the learner, and no artifact from the engine; the caller keeps the register.
---

# teach-back

Declarative preset. Selects the `teachback` playbook from the engine's closed
style enum (../engine.md) and, within it, the **teach-back direction** — the
user teaches the material back, the engine keeps a gap register, and the
no-grading invariant binds throughout. Its stop rule is the engine's
`### Stop at a closed gap register`, which lives in the engine and not here.
Behavior is the engine's; this file only names the playbook, the direction
inside it, fidelity, framing, and signal contract.
