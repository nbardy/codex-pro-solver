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
- `PRO_SOLVER_ATTEMPTS`
- `PRO_SOLVER_MAX_PARALLEL`
- `PRO_SOLVER_CURRENT`
- `PRO_SOLVER_TOPIC`
- `PRO_SOLVER_TIMEOUT`
- `PRO_SOLVER_ROOT`

Example:

```bash
PRO_SOLVER_ATTEMPTS=4 \
PRO_SOLVER_CURRENT=1 \
~/.codex/skills/private/pro-solver/scripts/run.sh "evaluate AI coding agents"
```

## How It Works

`scripts/run.sh`:

- writes the task into a pipeline folder
- runs one exploration pass
- runs several isolated attempts in parallel
- runs one synthesis pass
- stores all stage artifacts on disk for inspection

The prompts for each stage live under `prompts/`.

## Notes

- This repo is the shareable packaging for the skill.
- The actual skill name remains `pro`, as defined in `SKILL.md`.
- If you modify the prompts or runner, keep relative paths intact so the script can find its prompt files.
