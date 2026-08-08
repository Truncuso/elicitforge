---
style: socratic
fidelity: mid
framing: Resolve one grilling ticket on a wayfind decision map — the ticket names a decision the effort cannot move past, and the run either settles it or names precisely what still blocks it. One ticket per run, dependencies resolved before dependents, and the resolution notes become the record the rest of the map is built on.
output_contract: Emits RESOLVED_TERM (with optional RELATED) whenever a probe settles a term the map depends on, ADR_CANDIDATE with its required WHY line for every resolution passing the three-condition gate (hard-to-reverse, surprising-without-context, real-trade-off), and HANDOFF_SUGGESTION with its required QUESTION line when the ticket cannot be closed in-band — research or expert for the ones needing outside input, deferred when the map parks the ticket deliberately. The engine writes no ticket and no map; the caller applies the resolution to both.
---

# wayfind-probe

Declarative preset. Selects the `socratic` playbook from the engine's closed
style enum (../engine.md) — one question at a time with a recommended answer,
an opening confidence number, want-vs-should-want probing, concrete scenarios
stress-testing the ticket's stated boundaries, and the predictive-confidence
stop. Behavior is the engine's; this file only names the playbook, fidelity,
framing, and signal contract.
