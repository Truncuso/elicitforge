# elicitforge

A harness-agnostic **interview engine**: a one-question-at-a-time elicitation
loop that pressure-tests plans, specs, and ideas, and emits structured output
signals a caller can act on.

## Layout

```
core/
  presets/      interview presets (question sets, stop rules)
  references/   the signals contract and interview conduct rules
  evals/        deterministic, offline eval harness
```

`core/` is deliberately free of any host-harness-specific paths, tools, or
environment variables — adapters live outside it.

## Status

Pre-1.0, semver-tagged from first release.

## License

MIT — see [LICENSE](LICENSE).
