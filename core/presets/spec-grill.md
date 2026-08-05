---
style: socratic
fidelity: mid
framing: Grill a drafted spec at its approval gate before it is accepted — walk the design tree depth-first, resolve dependencies before dependents, and surface what the draft leaves unstated. The work under grilling is a shareable build, so decisions are treated as ones other people will have to live with.
output_contract: Emits RESOLVED_TERM (with optional RELATED) whenever a glossary challenge settles a spec term, ADR_CANDIDATE with its required WHY line for every decision passing the three-condition gate (hard-to-reverse, surprising-without-context, real-trade-off), and HANDOFF_SUGGESTION with its required QUESTION line — high-fidelity when the question outgrows the current run, research, expert, or user-judgment otherwise. The engine writes no spec text and no ADR; the caller owns the revision and the decision record.
---

# spec-grill

Declarative preset. Selects the `socratic` playbook from the engine's closed
style enum (core/engine.md) — one question at a time with a recommended answer,
opening confidence number, predictive-confidence stop, want-vs-should-want
probing, glossary challenge, code cross-reference.

`style` stays `socratic` at every fidelity. Running this preset at
`fidelity: high` promotes the socratic playbook's register to its adversarial
variant — that promotion is a rule inside the engine's playbook, not a field
here and not a second preset file. The style enum stays closed at five members
and callers select this preset regardless of the fidelity they run it at.
