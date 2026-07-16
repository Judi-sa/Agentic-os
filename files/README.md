# Agentic OS

A governance system for autonomous Claude agents.

Claude can now work alone for hours, spawn its own sub-agents, and defend its own mistakes very well. Used alone, that is an expensive way to generate confident errors. Used inside a real system, it is closer to hiring an employee for a few dollars a day.

Agentic OS is that system: a non-negotiable constitution, an independent verifier, a trust registry that grants or removes autonomy based on track record, and a self-improvement loop that never rewrites its own rules.

---

## Why this exists

The model was never the problem. The real challenge is building a system that stays reliable once you stop watching it.

Three principles run through every file here:

- **Laws, not advice.** Every rule is a `NEVER`, a command that can be checked by a script, or a fixed output format. If a rule cannot fit one of those three shapes, it does not belong in the constitution.
- **Nothing grades its own work.** An agent proposes, `verify.sh` decides. No exceptions.
- **Everything that succeeds once keeps being watched.** Trust is earned per skill, tracked, and audited weekly even once autonomous.

---

## What's inside

| File | Role |
|---|---|
| `CLAUDE.md` | The constitution. 12 numbered laws, an instruction hierarchy that blocks prompt injection from files or web content, and the trust registry rules. Read-only for agents. |
| `AGENTS.md` | Agent roster (Conductor, Worker, Critic, Retro, Verify), the 7-step thinking protocol every worker inherits from the Conductor, and the mandatory brief format used for every delegation. |
| `verify.sh` | The independent verifier. Checks protected files, client data leaks, hardcoded secrets, build/lint/tests, project state freshness, and diff size. Exit 0 means commit is allowed. Exit 1 means the task stays open. |
| `retro.sh` | The weekly self-improvement loop. Aggregates verify logs, surfaces recurring failures, and writes a proposal for human review. It never applies a change on its own. |

---

## Quickstart

1. Copy the four files into your repo root, `verify.sh` and `retro.sh` go into `scripts/`
2. `chmod +x scripts/verify.sh scripts/retro.sh`
3. Create `goals/`, `tasks/open/`, `tasks/done/`, `trust/`, `logs/`, `proposals/`
4. Add `current-state.md` to `.gitignore`
5. Run `./scripts/verify.sh` once to confirm it executes (it should fail cleanly on a fresh repo, that is expected)
6. Write your first task in `tasks/open/`

That's it. The constitution is now the highest authority in the repo, above any single prompt.

---

## The loop

```
Triage → Conductor briefs a Worker → Worker executes → verify.sh grades
                                                              ↓
                                              PASS → commit          FAIL → retry (max 3)
                                                                              ↓
                                                                    3 fails → STOP, escalate to human
```

Every brief carries the Conductor's thinking protocol (define done, smallest diff, verify before assuming, root cause only, one question upfront, brutal honesty, an elegance check) down to whichever model executes the task. The system's judgment is not lost when the work gets delegated to a smaller model.

---

## Self-improvement, on purpose, at two speeds

- **Fast lane:** every failure becomes one line in `tasks/lessons.md`, injected into the next relevant brief. No rule changes, so no approval needed.
- **Slow lane:** `retro.sh` runs weekly, aggregates the data, and writes a proposal. Only a human can turn that proposal into an actual change to the constitution, the agent roles, or the verifier.

A system that can rewrite its own guardrails does not have guardrails. This one cannot.

---

## Adapting it to your project

Nothing here is Claude-specific beyond the brief format, and nothing here is tied to any single project. Rename the identity block in `CLAUDE.md`, adjust the domains checked in `verify.sh` (client data patterns, secret formats) to match your own stack, and the rest holds.

---

## License

Add your license of choice here (MIT is a reasonable default for maximum reuse).

## Contributing

Issues and pull requests welcome, especially new `verify.sh` checks for stacks and secret formats not yet covered, and real-world failure patterns worth adding to the lessons format.
