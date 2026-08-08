---
style: teachback
fidelity: mid
framing: Test a user's grasp of already-settled material — retrieval practice that grades the recall, scoring each answer against the material and naming every gap it exposes. The material is not what is under examination here; the user's hold on it is, and the recommended answer is withheld until the user has committed to theirs, because a recalled answer that was shown first is not retrieval.
output_contract: Emits RESOLVED_TERM (with optional RELATED) when a recall gap forces a term to be restated precisely, ADR_CANDIDATE with its required WHY line when a quizzed answer exposes a decision passing the three-condition gate (hard-to-reverse, surprising-without-context, real-trade-off), and HANDOFF_SUGGESTION with its required QUESTION line for every gap the session cannot close — research or expert when closing it needs material the session does not have, user-judgment when the material itself turns out to be contested. The engine writes no findings artifact; the caller records the graded gaps and decides what they gate.
---

# quiz-back

Declarative preset. Selects the `teachback` playbook from the engine's closed
style enum (../engine.md) and, within it, the **quiz-back direction** — the
engine tests the user on settled material and grades the recall, naming and
reporting every gap. Its stop rule is the engine's
`### Stop at a settled recall profile`, which lives in the engine and not here.
Behavior is the engine's; this file only names the playbook, the direction
inside it, fidelity, framing, and signal contract.
