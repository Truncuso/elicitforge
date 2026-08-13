---
style: divergent
fidelity: mid
framing: Widen the field of possible answers before narrowing it — a two-phase session that first generates options without judging them, naming the axes they vary along, and then closes generation and sorts what was produced into a decision, keeping every option that lost together with the reason it lost. The subject here is not a plan to be defended but a space to be mapped, so the first plausible answer is treated as one sample rather than as the answer.
output_contract: Leaves a design record as its artifact — the framing that opened the session, the axes of variation, the options under each axis, the option chosen, and every rejected option with the reason it lost. Emits RESOLVED_TERM (with optional RELATED) when generation forces a term to be pinned down before two options can be compared, ADR_CANDIDATE with its required WHY line for each narrowing choice meeting the three-condition gate (hard-to-reverse, surprising-without-context, real-trade-off), and HANDOFF_SUGGESTION with its required QUESTION line whenever an option cannot be evaluated without material the session does not have. The engine writes no artifact; the caller records the design and decides what it gates.
---

# brainstorm

Declarative preset. Selects the `divergent` playbook from the engine's closed
style enum (../engine.md), which runs a divergence phase and then a convergence
phase inside that one playbook. Convergence is a phase of that playbook, not a
second style and not a second style field — this preset selects exactly one
style, and the phase switch is the engine's to make.

The divergence phase stops on the engine's
`### Stop at a saturated option space`, which lives in the engine and not here;
the convergence phase ends on the playbook's own completion condition, when
every option is either chosen or rejected with a stated reason. Behavior is the
engine's; this file only names the playbook, fidelity, framing, and signal
contract.
