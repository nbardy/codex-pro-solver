#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPTS_DIR="$SKILL_DIR/prompts"

usage() {
  cat <<'EOF'
Usage:
  run.sh "task description"
  run.sh < task.md

Environment overrides:
  PRO_SOLVER_MODEL     Optional model passed to `codex exec -m`
  PRO_SOLVER_ATTEMPTS  Number of isolated attempts to generate (default: 3)
  PRO_SOLVER_MAX_PARALLEL  Max concurrent attempt runs (default: PRO_SOLVER_ATTEMPTS)
  PRO_SOLVER_CURRENT   Set to 1 to add explicit current-info/source-verification instructions
  PRO_SOLVER_TOPIC     Optional explicit topic slug; otherwise derived from the task
  PRO_SOLVER_TIMEOUT   Per-stage timeout in seconds (default: 1200)
  PRO_SOLVER_ROOT      Output root (default: .codex-pipeline/topics)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

TASK_INPUT="${*:-}"
if [[ -z "$TASK_INPUT" ]]; then
  if [[ -t 0 ]]; then
    echo "Missing task description." >&2
    usage >&2
    exit 1
  fi
  TASK_INPUT="$(cat)"
fi

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
}

derive_topic_slug() {
  printf '%s' "$1" \
    | tr '\n' ' ' \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
    | cut -c1-80 \
    | {
        IFS= read -r raw
        slugify "$raw"
      }
}

run_with_timeout() {
  local timeout_s="$1"
  shift

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_s" "$@"
    return
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_s" "$@"
    return
  fi

  python3 -c '
import signal
import subprocess
import sys

timeout_s = int(sys.argv[1])
cmd = sys.argv[2:]
proc = subprocess.Popen(cmd)

def on_alarm(signum, frame):
    try:
        proc.terminate()
    finally:
        raise TimeoutError(f"Timed out after {timeout_s} seconds")

signal.signal(signal.SIGALRM, on_alarm)
signal.alarm(timeout_s)
try:
    rc = proc.wait()
finally:
    signal.alarm(0)
sys.exit(rc)
' "$timeout_s" "$@"
}

TOPIC_RAW="${PRO_SOLVER_TOPIC:-}"
if [[ -n "$TOPIC_RAW" ]]; then
  TOPIC_SLUG="$(slugify "$TOPIC_RAW")"
else
  TOPIC_SLUG="$(derive_topic_slug "$TASK_INPUT")"
  TOPIC_RAW="$TOPIC_SLUG"
fi

if [[ -z "$TOPIC_SLUG" ]]; then
  echo "Topic produced an empty slug from task input." >&2
  exit 1
fi

PIPELINE_ROOT="${PRO_SOLVER_ROOT:-.codex-pipeline/topics}"
ROOT="$PIPELINE_ROOT/$TOPIC_SLUG"
EXPLORATION_DIR="$ROOT/exploration"
SYNTHESIS_DIR="$ROOT/synthesis"
TIMEOUT_S="${PRO_SOLVER_TIMEOUT:-1200}"
ATTEMPT_COUNT="${PRO_SOLVER_ATTEMPTS:-3}"
MAX_PARALLEL="${PRO_SOLVER_MAX_PARALLEL:-$ATTEMPT_COUNT}"

if ! [[ "$ATTEMPT_COUNT" =~ ^[0-9]+$ ]] || [[ "$ATTEMPT_COUNT" -lt 1 ]]; then
  echo "PRO_SOLVER_ATTEMPTS must be a positive integer." >&2
  exit 1
fi

if ! [[ "$MAX_PARALLEL" =~ ^[0-9]+$ ]] || [[ "$MAX_PARALLEL" -lt 1 ]]; then
  echo "PRO_SOLVER_MAX_PARALLEL must be a positive integer." >&2
  exit 1
fi

mkdir -p "$EXPLORATION_DIR" "$SYNTHESIS_DIR"
for ((i = 1; i <= ATTEMPT_COUNT; i++)); do
  mkdir -p "$ROOT/attempt_$i"
done

printf '%s\n' "$TASK_INPUT" > "$ROOT/input.md"

MODEL_ARGS=()
if [[ -n "${PRO_SOLVER_MODEL:-}" ]]; then
  MODEL_ARGS=(-m "$PRO_SOLVER_MODEL")
fi

CURRENT_INFO_BLOCK=""
if [[ "${PRO_SOLVER_CURRENT:-0}" == "1" ]]; then
  CURRENT_INFO_BLOCK=$'\nCurrent-information requirement:\n- Treat this as a time-sensitive task.\n- Use shell-accessible public web sources when needed to verify current facts.\n- Prefer primary sources, company IR pages, exchange filings, and clearly dated reputable reporting.\n- Record concrete dates and URLs in the written artifacts.\n- Distinguish verified facts from inference.\n'
fi

run_stage() {
  local stage_name="$1"
  local output_file="$2"
  local prompt_file="$3"
  local -a cmd

  cmd=(
    codex exec
    --skip-git-repo-check
    --sandbox workspace-write
  )

  if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${MODEL_ARGS[@]}")
  fi

  cmd+=(
    -o "$output_file"
    -
  )

  echo "== $stage_name =="
  run_with_timeout "$TIMEOUT_S" "${cmd[@]}" < "$prompt_file"
}

attempt_strategy() {
  local attempt_n="$1"

  case "$attempt_n" in
    1)
      cat <<'EOF'
Attempt-specific direction:
- Optimize for simplicity and robustness.
- Minimize moving parts and hidden assumptions.
- Prefer the most defensible default answer.
EOF
      ;;
    2)
      cat <<'EOF'
Attempt-specific direction:
- Optimize for highest upside, performance relevance, or ambition.
- Lean into the strongest thesis if current evidence supports it.
- Accept more complexity if it materially sharpens the recommendation.
EOF
      ;;
    3)
      cat <<'EOF'
Attempt-specific direction:
- Optimize for elegance, novelty, or a hybrid rethink.
- Challenge the baseline framing and look for a cleaner ranking model.
- Keep the result coherent rather than merely contrarian.
EOF
      ;;
    *)
      cat <<EOF
Attempt-specific direction:
- Produce a genuinely different attempt from attempts 1-$((attempt_n - 1)).
- Optimize for a distinct angle such as valuation asymmetry, catalyst timing, portfolio construction, cycle-normalized earnings, or scope expansion.
- Explicitly state what makes this attempt non-duplicative.
EOF
      ;;
  esac
}

run_attempt_stage() {
  local attempt_n="$1"
  local prompt_file

  prompt_file="$(mktemp)"
  cat "$PROMPTS_DIR/02_attempt.md" > "$prompt_file"
  cat >> "$prompt_file" <<EOF

Topic: $TOPIC_RAW
Attempt number: $attempt_n
Task file: $ROOT/input.md
Exploration folder: $EXPLORATION_DIR
Output folder: $ROOT/attempt_$attempt_n
Repository root: $(pwd)
$CURRENT_INFO_BLOCK
$(attempt_strategy "$attempt_n")
EOF

  run_stage "Stage 2.$attempt_n: attempt $attempt_n" "$ROOT/attempt_$attempt_n/_summary.txt" "$prompt_file"
  rm -f "$prompt_file"
}

wait_for_slot() {
  local max_parallel="$1"

  while true; do
    local running
    running="$(jobs -pr | wc -l | tr -d ' ')"
    if [[ "$running" -lt "$max_parallel" ]]; then
      break
    fi
    sleep 1
  done
}

EXPLORE_PROMPT="$(mktemp)"
SYNTH_PROMPT="$(mktemp)"
trap 'rm -f "$EXPLORE_PROMPT" "$SYNTH_PROMPT"' EXIT

cat "$PROMPTS_DIR/01_explore.md" > "$EXPLORE_PROMPT"
cat >> "$EXPLORE_PROMPT" <<EOF

Topic: $TOPIC_RAW
Task file: $ROOT/input.md
Output folder: $EXPLORATION_DIR
Repository root: $(pwd)
$CURRENT_INFO_BLOCK
EOF

run_stage "Stage 1: exploration" "$EXPLORATION_DIR/_summary.txt" "$EXPLORE_PROMPT"

declare -a ATTEMPT_PIDS=()
for ((i = 1; i <= ATTEMPT_COUNT; i++)); do
  wait_for_slot "$MAX_PARALLEL"
  run_attempt_stage "$i" &
  ATTEMPT_PIDS+=("$!")
done

for pid in "${ATTEMPT_PIDS[@]}"; do
  wait "$pid"
done

cat "$PROMPTS_DIR/03_synthesize.md" > "$SYNTH_PROMPT"
cat >> "$SYNTH_PROMPT" <<EOF

Topic: $TOPIC_RAW
Task file: $ROOT/input.md
Exploration folder: $EXPLORATION_DIR
Attempt folders:
$(
  for ((i = 1; i <= ATTEMPT_COUNT; i++)); do
    printf -- "- %s\n" "$ROOT/attempt_$i"
  done
)
Output folder: $SYNTHESIS_DIR
Repository root: $(pwd)
$CURRENT_INFO_BLOCK
EOF

run_stage "Stage 3: synthesis" "$SYNTHESIS_DIR/_summary.txt" "$SYNTH_PROMPT"

cat <<EOF
Pipeline complete.
Artifacts: $ROOT
Final solution: $SYNTHESIS_DIR/final_solution.md
EOF
