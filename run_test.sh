#!/usr/bin/env bash

HOSTS_FILE="vars/hosts"
TESTS_FILE="vars/test_types.yml"

# Extract databases and test types
DATABASES=($(yq eval '.all.children.databases.hosts | keys | .[]' "$HOSTS_FILE"))
TEST_TYPES=($(yq eval '.test_types | keys | .[]' "$TESTS_FILE"))

# Initialize variables
ANSIBLE_VERBOSITY=""
DATABASE=""
TEST_TYPE=""

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
    -test_type|-test)
      TEST_TYPE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-database <name>|*] [-test_type <name>|*]"
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

# Show available options if nothing was specified
if [[ -z "$DATABASE" || -z "$TEST_TYPE" ]]; then
  echo "Available options:"
  echo "  - databases: ${DATABASES[*]}"
  echo "  - test types: ${TEST_TYPES[*]}"
  echo
fi

# Prompt for database if not specified
if [[ -z "$DATABASE" ]]; then
    ask_for_input "database" "${DATABASES[@]}"
    DATABASE="$REPLY"
fi
echo

# Prompt for test type if not specified
if [[ -z "$TEST_TYPE" ]]; then
    ask_for_input "test type" "${TEST_TYPES[@]}"
    TEST_TYPE="$REPLY"
fi
echo

# Set the arrays for looping (handle wildcard)
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
  echo "Creating results directory at $RESULTS_DIR"
  mkdir -p "$RESULTS_DIR"
fi

for db in "${DATABASES_TO_RUN[@]}"; do
  for test in "${TEST_TYPES_TO_RUN[@]}"; do
    PLAYBOOK_PATH="$SCRIPT_DIR/tests/$db/$test.yml"

    if [[ ! -f "$PLAYBOOK_PATH" ]]; then
      echo "Skipping: Playbook does not exist at $PLAYBOOK_PATH"
      continue
    fi

    echo
    echo "========================================="
    echo "Running playbook:"
    echo "  Database: $db"
    echo "  Test:     $test"
    echo "========================================="
    echo

    echo "Launching in 3 seconds. Press 'X' to cancel."
    for i in 3 2 1; do
      echo "$i..."
      read -t 1 -n 1 key
      if [[ "$key" =~ [Xx] ]]; then
        echo "Cancelled by user."
        exit 0
      fi
    done

    ansible-playbook $ANSIBLE_VERBOSITY "$PLAYBOOK_PATH" \
      -e "database=$db test_type=$test results_dir=$RESULTS_DIR"
  done
done