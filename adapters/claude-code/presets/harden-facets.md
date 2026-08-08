---
style: socratic
fidelity: mid
framing: "Harden a decomposed work package facet by facet — verification strategy, constraints, boundaries, and the open questions blocking readiness — until each facet is concrete enough to execute against. Shareable-build framing: the answers become the contract an executor is held to, not notes for the author alone."
output_contract: Emits RESOLVED_TERM (with optional RELATED) when a facet's terminology is settled, ADR_CANDIDATE with its required WHY line when hardening exposes a decision passing the three-condition gate, and HANDOFF_SUGGESTION with its required QUESTION line for every facet that cannot be closed in-band — deferred for facets parked deliberately, expert or research for the ones needing outside input, high-fidelity when a facet's answer depends on observing the built thing rather than more talk (the caller's spike escape hatch). The engine edits no work package; the caller applies the answers to the plan.
---

# harden-facets

Declarative preset. Selects the `socratic` playbook from the engine's closed
style enum (../engine.md) — one question at a time with a recommended answer,
dependencies resolved before dependents, concrete scenarios used to stress-test
stated boundaries, and the predictive-confidence stop. Inside that playbook it
selects the engine's `### Ladder up-chain from a stated constraint` technique,
which lives in the engine and not here: one *why does that matter* per stated
constraint, so a hardened facet records the reason behind a boundary and not
only the boundary itself. Behavior is the engine's; this file only names the
playbook, the technique it selects inside it, fidelity, framing, and signal
contract.
