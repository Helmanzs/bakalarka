#!/usr/bin/env bash

HOST_GROUP="local"
HOSTS_FILE="inventory/${HOST_GROUP}"
PROFILES_FILE="vars/resource_profiles.yml"

ANSIBLE_VERBOSITY=""
DATABASE=""
REPEAT=1
PROFILE=""


WORKERS=""
DURATION=""
BATCH_SIZE=""
TS_STEP_MS=""


WORKER_OPTIONS=(1 2 4 8 16)
DURATION_OPTIONS=(30 60 120 300 600)
BATCH_OPTIONS=(100 500 1000 5000 10000)
TS_STEP_OPTIONS=(100 500 1000 5000)

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|-vv|-vvv|-vvvv)
      ANSIBLE_VERBOSITY="$1"
      shift
      ;;
    -database|-d)
      DATABASE="$2"
      shift 2
      ;;
    -r|-repeat)
      REPEAT="$2"
      shift 2
      ;;
    -i|-inventory)
      HOST_GROUP="$2"
      HOSTS_FILE="inventory/${HOST_GROUP}"
      shift 2
      ;;
    -p|-profile)
      PROFILE="$2"
      shift 2
      ;;
    -workers|-w)
      WORKERS="$2"
      shift 2
      ;;
    -duration|-dur)
      DURATION="$2"
      shift 2
      ;;
    -batch|-b)
      BATCH_SIZE="$2"
      shift 2
      ;;
    -step|-s)
      TS_STEP_MS="$2"
      shift 2
      ;;
    -h|-help|--help)
      cat >&2 <<EOF
Usage: $0 [OPTIONS]

Options:
  -database  | -d   <name|*>   Database to test (required, or interactive)
  -profile   | -p   <name>     Resource profile (small | medium | large)
  -repeat    | -r   <N>        Number of full test repetitions      (default: 1)
  -workers   | -w   <N>        Parallel insert clients              (default: interactive)
  -duration  | -dur <s>        Test duration in seconds             (default: interactive)
  -batch     | -b   <N>        Rows per batch per worker            (default: interactive)
  -step      | -s   <ms>       Milliseconds between row timestamps  (default: interactive)
  -inventory | -i   <group>    Inventory group name                 (default: local)
  -v/-vv/-vvv/-vvvv            Ansible verbosity

Examples:
  # Fully interactive
  $0

  # Non-interactive quick run
  $0 -d clickhousedb -p medium -w 4 -dur 60 -b 500 -s 100

  # Run all databases, 4 workers, 2 minutes, repeat 3 times
  $0 -d '*' -p medium -w 4 -dur 120 -b 1000 -r 3
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run '$0 --help' for usage." >&2
      exit 1
      ;;
  esac
done

print_options() {
  local label="$1"; shift
  local options=("$@")
  {
    echo "Options for ${label}:"
    for opt in "${options[@]}"; do
      echo "  - ${opt}"
    done
  } >&2
}

ask_for_choice() {
  local label="$1"; shift
  local options=("$@")
  local input valid retries=5

  for (( i=1; i<=retries; i++ )); do
    print_options "$label" "${options[@]}"
    echo >&2
    read -rp "Choose ${label} (or enter a custom value): " input

    # Accept exact match from list
    valid=0
    for opt in "${options[@]}"; do
      if [[ "$input" == "$opt" ]]; then
        valid=1
        break
      fi
    done

    # Also accept any positive integer as a custom value
    if [[ $valid -eq 0 && "$input" =~ ^[1-9][0-9]*$ ]]; then
      valid=1
    fi

    if [[ $valid -eq 1 ]]; then
      REPLY="$input"
      return 0
    fi

    >&2 echo "Invalid value '${input}', try again ($((retries - i)) attempts left)..."
    sleep 1
  done

  >&2 echo "Too many invalid attempts for ${label}. Exiting."
  exit 1
}

ask_for_database() {
  local databases=("$@")
  local input valid retries=5

  for (( i=1; i<=retries; i++ )); do
    {
      echo "Options for database:"
      for db in "${databases[@]}"; do
        echo "  - ${db}"
      done
      echo "  - * (all databases)"
    } >&2
    echo >&2
    read -rp "Choose database: " input

    valid=0
    if [[ "$input" == "*" ]]; then
      valid=1
    else
      for db in "${databases[@]}"; do
        if [[ "$input" == "$db" ]]; then
          valid=1
          break
        fi
      done
    fi

    if [[ $valid -eq 1 ]]; then
      REPLY="$input"
      return 0
    fi

    >&2 echo "Invalid database '${input}', try again ($((retries - i)) attempts left)..."
    sleep 1
  done

  >&2 echo "Too many invalid attempts for database. Exiting."
  exit 1
}

if [[ ! -f "$HOSTS_FILE" ]]; then
  echo "ERROR: Inventory file not found: $HOSTS_FILE" >&2
  exit 1
fi

DATABASES=($(yq eval '.databases.hosts // {} | keys | .[]' "$HOSTS_FILE"))

if [[ ${#DATABASES[@]} -eq 0 ]]; then
  echo "ERROR: No databases found in inventory group [databases] in $HOSTS_FILE" >&2
  exit 1
fi

echo
echo "============================================="
echo "  Live Insert Benchmark"
echo "============================================="
echo

if [[ -z "$DATABASE" ]]; then
  ask_for_database "${DATABASES[@]}"
  DATABASE="$REPLY"
  echo
fi

if [[ -z "$WORKERS" ]]; then
  echo "Number of parallel insert workers (simulates N simultaneous data sources)." >&2
  ask_for_choice "workers" "${WORKER_OPTIONS[@]}"
  WORKERS="$REPLY"
  echo
fi

if [[ -z "$DURATION" ]]; then
  echo "Test duration in seconds (how long each worker keeps inserting)." >&2
  ask_for_choice "duration (seconds)" "${DURATION_OPTIONS[@]}"
  DURATION="$REPLY"
  echo
fi

if [[ -z "$BATCH_SIZE" ]]; then
  echo "Rows per batch per worker (larger = fewer round-trips, higher throughput)." >&2
  ask_for_choice "batch size (rows)" "${BATCH_OPTIONS[@]}"
  BATCH_SIZE="$REPLY"
  echo
fi

if [[ -z "$TS_STEP_MS" ]]; then
  echo "Milliseconds between row timestamps within a batch (100ms = 10 rows/s per vehicle)." >&2
  ask_for_choice "timestamp step (ms)" "${TS_STEP_OPTIONS[@]}"
  TS_STEP_MS="$REPLY"
  echo
fi

RAM=""
CPU=""

if [[ -n "$PROFILE" ]]; then
  RAM=$(yq eval ".profiles.${PROFILE}.ram_limit" "$PROFILES_FILE")
  CPU=$(yq eval ".profiles.${PROFILE}.cpu_limit" "$PROFILES_FILE")

  if [[ "$RAM" == "null" || -z "$RAM" ]]; then
    echo "ERROR: Unknown RAM for profile '$PROFILE'" >&2
    exit 1
  fi
  if [[ "$CPU" == "null" || -z "$CPU" ]]; then
    echo "ERROR: Unknown CPU for profile '$PROFILE'" >&2
    exit 1
  fi
fi

if [[ "$DATABASE" == "*" ]]; then
  DATABASES_TO_RUN=("${DATABASES[@]}")
else
  DATABASES_TO_RUN=("$DATABASE")
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

echo
echo "============================================="
echo "  Live Insert Test Configuration"
echo "============================================="
printf "  %-22s %s\n" "Databases:"    "${DATABASES_TO_RUN[*]}"
printf "  %-22s %s\n" "Profile:"      "${PROFILE:-unset}"
printf "  %-22s %s\n" "RAM:"          "${RAM:-unset}"
printf "  %-22s %s\n" "CPU:"          "${CPU:-unset}"
printf "  %-22s %s\n" "Workers:"      "$WORKERS"
printf "  %-22s %s\n" "Duration (s):" "$DURATION"
printf "  %-22s %s\n" "Batch size:"   "$BATCH_SIZE"
printf "  %-22s %s\n" "TS step (ms):" "$TS_STEP_MS"
printf "  %-22s %s\n" "Repetitions:"  "$REPEAT"
printf "  %-22s %s\n" "Results dir:"  "$RESULTS_DIR"
echo "============================================="
echo
echo "Estimated rows per worker: $(( (DURATION / 1) * BATCH_SIZE )) (upper bound, depends on insert latency)"
echo "Total estimated rows:      $(( (DURATION / 1) * BATCH_SIZE * WORKERS )) across all workers"
echo

if [[ -t 0 ]]; then
  echo "Launching in 3 seconds. Press 'X' to cancel."
  for i in 3 2 1; do
    echo "$i..."
    read -t 1 -n 1 key || true
    if [[ "$key" =~ [Xx] ]]; then
      echo "Cancelled by user."
      exit 0
    fi
  done
else
  echo "Non-interactive mode detected (no TTY). Skipping countdown."
fi

PLAYBOOK_PATH="$SCRIPT_DIR/tests/test.yml"

if [[ ! -f "$PLAYBOOK_PATH" ]]; then
  echo "ERROR: Playbook not found at $PLAYBOOK_PATH" >&2
  exit 1
fi

for (( run=1; run<=REPEAT; run++ )); do
  echo
  echo "========== REPEAT RUN $run / $REPEAT =========="

  for db in "${DATABASES_TO_RUN[@]}"; do
    echo
    echo "========================================="
    echo "  Database:   $db"
    echo "  Test:       live_insert"
    echo "  Workers:    $WORKERS"
    echo "  Duration:   ${DURATION}s"
    echo "  Batch:      $BATCH_SIZE rows"
    echo "  TS step:    ${TS_STEP_MS}ms"
    echo "  Run:        $run / $REPEAT"
    echo "========================================="
    echo

    ansible-playbook $ANSIBLE_VERBOSITY "$PLAYBOOK_PATH" \
      -e "database=$db"                                  \
      -e "test_type=live_insert"                         \
      -e "results_dir=$RESULTS_DIR"                      \
      -e "run=$run"                                      \
      -e "profile=${PROFILE:-}"                          \
      -e "workers=$WORKERS"                  \
      -e "duration=$DURATION"                \
      -e "batch_size=$BATCH_SIZE"            \
      -e "ts_step_ms=$TS_STEP_MS"

    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
      echo
      echo "WARNING: Playbook exited with code $EXIT_CODE for database '$db' on run $run." >&2
      echo "         Continuing with remaining databases/runs..." >&2
    fi
  done
done

echo
echo "============================================="
echo "  All live_insert runs complete."
echo "  Results written to: $RESULTS_DIR/live_insert.ndjson"
echo "============================================="