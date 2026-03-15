---
name: pro
description: "Runs a staged deep-thinking workflow from one freeform task prompt using multiple isolated `codex exec` passes: exploration, multiple parallel attempts, and a final synthesis. Use when the user invokes `$pro`, wants stronger separation between analysis stages, or wants a mock Pro workflow with good defaults and minimal arguments."
---

# Pro

Use this skill when a task benefits from explicit stage boundaries instead of one long Codex session.

Workflow:
1. Capture the task in a pipeline folder derived from the prompt.
2. Run one exploration pass that maps requirements, constraints, unknowns, and architecture.
3. Run fresh attempt passes either as a flat pool or in strict rounds.
4. Run one synthesis pass that compares attempts and produces a final solution.

The orchestration is implemented by `scripts/run.sh`. Prefer the script over manually replaying the workflow.

Execution modes:
- Round mode: `PRO_SOLVER_WIDTH=<attempts-per-round>` and `PRO_SOLVER_ROUNDS=<num-rounds>`
- Flat mode: `PRO_SOLVER_ATTEMPTS=<total-attempts>` and `PRO_SOLVER_MAX_PARALLEL=<concurrency>`

## Usage

In chat:

```bash
$pro research korean memory stocks
```

From the shell:

```bash
~/.codex/skills/private/pro-solver/scripts/run.sh "research korean memory stocks"
```

Artifacts are written to:

```text
.codex-pipeline/topics/<derived-topic>/
```

## Rules

- Keep each stage isolated. Do not collapse the workflow into one run.
- Use the filesystem as the handoff boundary between stages.
- Each stage should print only a short completion summary to stdout.
- Attempts must stay meaningfully different.
- In flat mode: attempt 1 should be the simplest and most robust.
- In flat mode: attempt 2 should be the highest performance or most ambitious.
- In flat mode: attempt 3 should be elegant, novel, or a hybrid rethink.
- In round mode: slot 1, 2, and 3 use those same archetypes within each round.
- Later rounds must stay non-duplicative relative to earlier rounds, especially within the same slot.
- Attempts or slots 4+ should be explicitly non-duplicative.
- Final synthesis should explicitly compare tradeoffs and reject weak ideas.

## Files

- Prompt templates live in `prompts/`.
- The orchestrator script is `scripts/run.sh`.
- The script supports optional environment overrides: `PRO_SOLVER_MODEL`, `PRO_SOLVER_WIDTH`, `PRO_SOLVER_ROUNDS`, `PRO_SOLVER_ATTEMPTS`, `PRO_SOLVER_MAX_PARALLEL`, `PRO_SOLVER_CURRENT`, `PRO_SOLVER_TOPIC`, `PRO_SOLVER_TIMEOUT`, and `PRO_SOLVER_ROOT`.
