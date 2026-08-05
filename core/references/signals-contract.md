---
name: signals-contract
title: Interview engine — structured output signals contract
contract_version: 1.0
status: frozen
---

# Signals contract v1.0

This contract is **frozen**. Signal names, line grammars, and the
`HANDOFF_SUGGESTION` enum are stable for the whole `1.0` line: consumers may
rely on exact token matching. Adding a signal type is a minor bump; changing or
removing a signal name, its grammar, or an enum member is a major bump.

A signal is a line-oriented, plain-text emission from the interview engine. It
is written into the interview transcript at the point it is produced, and — when
a sink is bound — additionally routed to that sink. The transcript is always the
emission of record; a sink is a delivery channel, never a replacement.

## Signal types

### `RESOLVED_TERM`

```
RESOLVED_TERM: <term> = <one-line definition>
RELATED: <comma-separated related terms>
```

Emitted when a glossary challenge settles a fuzzy term. The `RELATED` line is
optional; when present it MUST immediately follow the `RESOLVED_TERM` line.

- **Sink** — the project glossary document (`CONTEXT.md` by convention), appended
  as a term entry.
- **Sink absent (degrade)** — keep the signal in the transcript only, and emit a
  single closing summary block listing every resolved term so the caller can file
  them. Never drop the term; never fail the interview.

### `ADR_CANDIDATE`

```
ADR_CANDIDATE: <slug> — <one-line title>
WHY: <1-2 sentences on why this deserves an ADR>
```

Emitted when a decision passes the three-condition gate (hard-to-reverse,
surprising-without-context, real-trade-off). The `WHY` line is REQUIRED.

- **Sink** — the decision-record surface the caller declares (an ADR directory or
  a decisions section of the owning planning document).
- **Sink absent (degrade)** — keep the signal in the transcript only and repeat
  it in the closing summary block. The engine never writes an ADR itself.

### `HANDOFF_SUGGESTION`

```
HANDOFF_SUGGESTION: <member>
QUESTION: <the specific question that needs external resolution>
```

Emitted when the interview hits a wall it cannot resolve from the user in-band.
The `QUESTION` line is REQUIRED.

- **Sink** — the caller's resumable state sink (a findings/ledger/handoff
  document the caller owns and can be re-invoked against).
- **Sink absent (degrade)** — degrade-to-assumptions per the engine's
  `unattended:` rule: record the lowest-risk assumption inline with a one-line
  rationale, continue, and emit `HANDOFF_SUGGESTION: user-judgment` so the
  assumption surfaces at the caller.

## Frozen `HANDOFF_SUGGESTION` enum

Exactly five members. Closed set — an emission outside this set is a contract
violation.

| Member | Meaning |
|---|---|
| `research` | The answer exists outside the room and needs to be looked up. |
| `expert:<role>` | Needs a named specialist role; `<role>` is a free-text suffix. |
| `user-judgment` | A pure preference or taste call only the user can make. |
| `high-fidelity` | The question needs a higher-fidelity model, tier, or effort than the current run. |
| `deferred` | Deliberately parked — not needed to make progress now. |

Only `expert:` carries a suffix; the other four members are emitted bare.

## Sink-binding rules

- Sink binding is the caller's responsibility and is declared before the
  interview starts. The engine never discovers or creates a sink.
- Sink absence is a normal, supported mode — every signal above declares a
  degrade path, and no degrade path aborts the interview.
- A bound sink that fails to accept a write degrades exactly as if it were
  absent, plus one transcript line naming the failed sink.
