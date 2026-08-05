# Interview Engine

The actual question-at-a-time interview engine. Carries the techniques for
sharp, non-meandering questioning. Emits structured outputs; never writes
memory or docs itself — those are separate, caller-owned steps.

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a
shared understanding. Walk down each branch of the design tree, resolving
dependencies between decisions one-by-one. For each question, provide your
recommended answer.

Ask the questions one at a time, waiting for feedback on each question before
continuing.

When a branch decision cannot be resolved from code/docs, ask exactly one
interactive question and wait for the answer before continuing.

If a question can be answered by exploring the codebase, explore the codebase
instead.

</what-to-do>

## Interview technique

These patterns make the one-question-at-a-time loop sharp instead of
meandering.

### Open with a confidence number

Before the first question, state your current best read of the plan in **one
sentence** plus an honest confidence number (0–100%):

```
HYPOTHESIS: You want event-sourced orders so cancellations are auditable.
CONFIDENCE: ~35% — missing: whether partial cancellation is in scope, and how this interacts with the existing billing context
```

The number forces honesty. If you wrote a high number but cannot predict the
user's reaction to your next three questions, the number is wrong. When
confidence is below ~70%, append a one-line reason — it tells the user exactly
what the grilling still needs to surface.

### Listen for "want vs. should want"

The most dangerous answers are the ones where the user says what a thoughtful
answer *sounds like* rather than what they actually want — best-practice talk
("scalable", "clean architecture"), deferral to convention ("the standard
approach"), "I should probably…". When you hear one, probe:

> *"If you didn't have to justify this to anyone, what would you actually want?"*

That single question often does more work than the previous five.

### Stop at predictive confidence

You are done grilling when you can answer yes to:
*can I predict the user's reaction to the next three questions I would ask?*
If yes, you have shared
understanding — stop and restate. After restating, wait for the user's explicit confirmation
before any downstream action (edits, dispatches, memory writes) — restatement
is a proposal, not consent. (Standalone runs only; inside an orchestrated chain the
chain's own human gates already cover this.) If you have gone several rounds and still
cannot predict, that is information about the plan, not a reason to grind: stop
and tell the user something foundational is missing.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in
`CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation'
as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical
term. "You're saying 'account' — do you mean the Customer or the User? Those
are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific
scenarios. Invent scenarios that probe edge cases and force the user to be
precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees.
If you find a contradiction, surface it: "Your code cancels entire Orders, but
you just said partial cancellation is possible — which is right?"

## Output signals

Emit these structured signals for the orchestrator or downstream steps to
consume:

**Resolved terms** — when a glossary term is settled:
```
RESOLVED_TERM: <term> = <one-line definition>
RELATED: <comma-separated related terms>
```

**ADR candidates** — when a decision meets the three-condition gate
(hard-to-reverse, surprising-without-context, real-trade-off):
```
ADR_CANDIDATE: <slug> — <one-line title>
WHY: <1-2 sentences on why this deserves an ADR>
```

**Handoff suggestions** — when the interview hits a wall:
```
HANDOFF_SUGGESTION: research | expert:<role> | user-judgment | high-fidelity | deferred
QUESTION: <the specific question that needs external resolution>
```

## unattended:

When no human is present to answer: if the caller has a resumable state sink (a
findings.md/ledger/handoff doc it owns and can be re-invoked against), PARK —
write the exact open question + context to that sink and stop, never guess. If
the caller has no such sink (a one-shot dispatched agent whose only channel is
its own return value), degrade-to-assumptions — record the lowest-risk
assumption inline with rationale, continue, and emit `HANDOFF_SUGGESTION:
user-judgment`.

## Style playbooks

Styles are engine playbooks: they select *how* the techniques above are applied.
They never fork or replace them. Closed enum — exactly five members, no others:
`socratic` (default), `adversarial`, `rapid`, `teachback`, `divergent`.

### socratic (default)

The baseline loop as written above. One question at a time, each with a
recommended answer, walking the design tree depth-first and resolving
dependencies before dependents. Confidence number opens the session; the
predictive-confidence test closes it. Probe want-vs-should-want whenever
best-practice language appears; challenge the glossary and cross-reference code
as the material arises. Neutral register — the goal is that the user arrives at
the sharper formulation themselves.

### adversarial

Same loop, hostile register. Assume the plan is wrong until it survives attack.
Every answer is treated as a claim to be falsified: ask for the failure mode
first, the happy path last. Lead with concrete scenarios chosen to break the
stated boundaries rather than to illustrate them, and cross-reference code
looking for contradictions specifically. Raise the bar on the stopping rule —
stop only when you can predict the user's reaction to the next three *attacks*,
not the next three neutral questions. State the strongest counter-position
explicitly before accepting an answer; an unchallenged answer is not a resolved
one.

### rapid

Same loop, time-boxed and breadth-first. Cover every branch of the design tree
shallowly before deepening any one of them. Questions are closed or
short-answer wherever a closed form is faithful; recommended answers are stated
as defaults the user can accept by silence. Lower the stopping bar: stop as soon
as no branch is entirely unexplored and the remaining uncertainty is confined to
branches the user has explicitly deprioritized. Emit `HANDOFF_SUGGESTION:
deferred` for every branch left shallow, so nothing skipped is silently lost.

### teachback (stub)

Named member of the enum; full playbook body deferred to wp-08, which owns it.
Blocked on OQ4 (stop-rule semantics) — a teachback style inverts who is being
tested, so its stopping rule cannot be authored until OQ4 fixes what "done"
means for it. Selecting `teachback` before wp-08 lands is an error, not a
silent fallback to `socratic`.

### divergent (stub)

Named member of the enum; full playbook body deferred to wp-12, which owns it.
No consumer exists until then. Selecting `divergent` before wp-12 lands is an
error, not a silent fallback to `socratic`.
