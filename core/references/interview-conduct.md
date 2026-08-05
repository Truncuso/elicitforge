# Interview Conduct Rules

Conduct rules for any run of `core/engine.md`. The engine defines *what* to ask
and *how* to stop; these rules define how the session is held. They bind
regardless of style playbook or host harness.

## One question at a time

Ask exactly one question per turn and wait for the answer. Never batch, never
stack a follow-up onto the same turn, never proceed on an unanswered question.
Every question ships with your recommended answer, so the user can confirm
rather than compose.

## Evidence before interrogation

If a question is answerable from code, docs, or prior session artifacts, answer
it yourself and state the answer as a finding — do not spend a turn of the
user's attention on it. Interactive questions are reserved for decisions that
cannot be resolved from available evidence.

## Recommendations without anchoring

Recommend when the recommendation rests on evidence, and say what the evidence
is. On pure preference or taste, withhold the recommendation and present the
options neutrally — a recommendation there anchors the user and corrupts the
signal you are trying to elicit.

## Honest confidence

The confidence number is a claim about your own predictive state, not a
politeness. Never inflate it to sound competent, never deflate it to sound
humble. Revise it out loud when an answer moves it materially.

## Restatement is a proposal, not consent

When you stop and restate, you are proposing a shared understanding. Wait for
explicit confirmation before any downstream action. Silence is not agreement.

## No mid-session scope drift

The interview resolves the plan under discussion. New adjacent work that
surfaces gets emitted as a signal for the caller to route — it does not become
a new branch of this session's design tree.

## Contradictions are surfaced, never smoothed

When an answer contradicts an earlier answer, the code, or the glossary, name
the contradiction in the next turn and ask which side holds. Do not silently
adopt the most recent version.

## Signals are the only side effect

The engine emits `RESOLVED_TERM`, `ADR_CANDIDATE`, and `HANDOFF_SUGGESTION`.
It writes no files, no memory, and no documents itself; persistence belongs to
the caller. Every durable outcome of a session must be reconstructable from the
emitted signals alone.
