# codex-pro-solver

`codex-pro-solver` is a small Codex skill that runs a staged "Pro" workflow:

1. Exploration
2. Multiple isolated attempts
3. Final synthesis

It is designed for tasks where one long agent session is weaker than several clean passes with explicit handoff artifacts on disk.

## What Is In This Repo

```text
.
├── SKILL.md
├── prompts/
│   ├── 01_explore.md
│   ├── 02_attempt.md
│   └── 03_synthesize.md
└── scripts/
    └── run.sh
```

## Requirements

- `codex` CLI installed and working
- `bash`
- `python3`
- standard shell tools available on macOS or Linux
- optional: `timeout` or `gtimeout`

## Install

### Option 1: Clone Into Your Codex Skills Directory

If you want the skill available directly to Codex by name, clone it into your local skills directory:

```bash
mkdir -p ~/.codex/skills/private
git clone https://github.com/nbardy/codex-pro-solver.git ~/.codex/skills/private/pro-solver
```

After that, Codex can discover it as the `pro` skill from the `SKILL.md` metadata.

### Option 2: Copy It Manually

Clone it anywhere, then copy the repo contents into:

```bash
~/.codex/skills/private/pro-solver
```

The important part is that `SKILL.md`, `prompts/`, and `scripts/` stay together.

## Usage

In chat:

```bash
$pro research korean memory stocks
```

From a shell:

```bash
~/.codex/skills/private/pro-solver/scripts/run.sh "research korean memory stocks"
```

Artifacts are written to:

```text
.codex-pipeline/topics/<derived-topic>/
```

## Environment Overrides

The runner supports these optional environment variables:

- `PRO_SOLVER_MODEL`
- `PRO_SOLVER_WIDTH`
- `PRO_SOLVER_ROUNDS`
- `PRO_SOLVER_ATTEMPTS`
- `PRO_SOLVER_MAX_PARALLEL`
- `PRO_SOLVER_CURRENT`
- `PRO_SOLVER_TOPIC`
- `PRO_SOLVER_TIMEOUT`
- `PRO_SOLVER_ROOT`

## Execution Modes

The runner supports two execution models.

### 1. Round Mode

Use this when you want strict waves of work.

- `PRO_SOLVER_WIDTH` = attempts per round
- `PRO_SOLVER_ROUNDS` = number of rounds
- total attempts = `width * rounds`

Example:

```bash
PRO_SOLVER_WIDTH=3 \
PRO_SOLVER_ROUNDS=3 \
~/.codex/skills/private/pro-solver/scripts/run.sh "evaluate AI coding agents"
```

That runs:

- 1 exploration pass
- round 1: 3 attempts in parallel
- round 2: 3 attempts in parallel after round 1 fully finishes
- round 3: 3 attempts in parallel after round 2 fully finishes
- 1 synthesis pass

This is the right model for a true `3 x 3` run.

### 2. Flat Attempt Mode

This is the original behavior.

- `PRO_SOLVER_ATTEMPTS` = total attempts
- `PRO_SOLVER_MAX_PARALLEL` = concurrency cap

Example:

```bash
PRO_SOLVER_ATTEMPTS=9 \
PRO_SOLVER_MAX_PARALLEL=3 \
~/.codex/skills/private/pro-solver/scripts/run.sh "evaluate AI coding agents"
```

That gives 9 attempts total with up to 3 running at once, but not strict round boundaries.

Example:

```bash
PRO_SOLVER_WIDTH=3 \
PRO_SOLVER_ROUNDS=2 \
PRO_SOLVER_CURRENT=1 \
~/.codex/skills/private/pro-solver/scripts/run.sh "evaluate AI coding agents"
```

## How It Works

`scripts/run.sh`:

- writes the task into a pipeline folder
- runs one exploration pass
- runs attempts either as strict rounds or as a flat parallel pool
- runs one synthesis pass
- stores all stage artifacts on disk for inspection

The prompts for each stage live under `prompts/`.

## Notes

- This repo is the shareable packaging for the skill.
- The actual skill name remains `pro`, as defined in `SKILL.md`.
- If you modify the prompts or runner, keep relative paths intact so the script can find its prompt files.
