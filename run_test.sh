#!/usr/bin/env bash

HOST_GROUP="local"
HOSTS_FILE="inventory/${HOST_GROUP}"
TESTS_FILE="vars/test_types.yml"
PROFILES_FILE="vars/resource_profiles.yml"

ANSIBLE_VERBOSITY=""
DATABASE=""
TEST_TYPE=""
REPEAT=1
PROFILE=""

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
    -test_type|-test|-t)
      TEST_TYPE="$2"
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
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-database <name>|*] [-test_type <name>|*] [-profile <name>] [-r <1..N>] [-i <inventory>]"
      exit 1
      ;;
  esac
done

DATABASES=($(yq eval '.databases.hosts // {} | keys | .[]' "$HOSTS_FILE"))
TEST_TYPES=($(yq eval '.test_types[]' "$TESTS_FILE"))

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

ask_for_input() {
  local label="$1"; shift
  local options=("$@")
  local input
  local valid
  local retries=5
  for ((i=1; i<=retries; i++)); do
    print_options "$label" "${options[@]}"
    echo
    read -rp "Choose ${label}: " input
    valid=0
    for opt in "${options[@]}"; do
      if [[ "$input" == "$opt" ]]; then
        valid=1
        break
      fi
    done
    if [[ $valid -eq 1 ]]; then
      REPLY="$input"
      return 0
    fi
    >&2 echo "Invalid ${label}, try again ($((retries - i)) attempts left)..."
    sleep 2
  done
  >&2 echo "Too many invalid attempts for ${label}. Exiting."
  exit 1
}

if [[ -z "$DATABASE" || -z "$TEST_TYPE" ]]; then
  echo "Available options:"
  echo "  - databases: ${DATABASES[*]}"
  echo "  - test types: ${TEST_TYPES[*]}"
  echo
fi

if [[ -z "$DATABASE" ]]; then
    ask_for_input "database" "${DATABASES[@]}"
    DATABASE="$REPLY"
fi

echo

if [[ -z "$TEST_TYPE" ]]; then
    ask_for_input "test type" "${TEST_TYPES[@]}"
    TEST_TYPE="$REPLY"
fi

echo

RAM=""
CPU=""

if [[ -n "$PROFILE" ]]; then
  RAM=$(yq eval ".profiles.${PROFILE}.ram_limit" "$PROFILES_FILE")
  CPU=$(yq eval ".profiles.${PROFILE}.cpu_limit" "$PROFILES_FILE")

  if [[ "$RAM" == "null" || -z "$RAM" ]]; then
    echo "ERROR: Unknown RAM for profile '$PROFILE'"
    exit 1
  fi

  if [[ "$CPU" == "null" || -z "$CPU" ]]; then
    echo "ERROR: Unknown CPU for profile '$PROFILE'"
    exit 1
  fi
fi

echo

if [[ "$DATABASE" == "*" ]]; then
    DATABASES_TO_RUN=("${DATABASES[@]}")
else
    DATABASES_TO_RUN=("$DATABASE")
fi

if [[ "$TEST_TYPE" == "*" ]]; then
    TEST_TYPES_TO_RUN=("${TEST_TYPES[@]}")
else
    TEST_TYPES_TO_RUN=("$TEST_TYPE")
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

if [[ ! -d "$RESULTS_DIR" ]]; then
  mkdir -p "$RESULTS_DIR"
fi

for (( run=1; run<=REPEAT; run++ )); do
  echo
  echo "========== REPEAT RUN $run/$REPEAT =========="
  for db in "${DATABASES_TO_RUN[@]}"; do
    for test in "${TEST_TYPES_TO_RUN[@]}"; do
      PLAYBOOK_PATH="$SCRIPT_DIR/tests/test.yml"
      if [[ ! -f "$PLAYBOOK_PATH" ]]; then
        echo "Skipping: Playbook does not exist at $PLAYBOOK_PATH"
        continue
      fi
      echo
      echo "========================================="
      echo "Running playbook:"
      echo "  Database: $db"
      echo "  Test:     $test"
      echo "  RAM:      ${RAM:-unset}"
      echo "  CPU:      ${CPU:-unset} Core"
      echo "========================================="
      echo "  Run:      $run / $REPEAT"
      echo "========================================="
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
      ansible-playbook $ANSIBLE_VERBOSITY "$PLAYBOOK_PATH" -e "database=$db test_type=$test results_dir=$RESULTS_DIR run=$run profile=$PROFILE"
    done
  done
done
