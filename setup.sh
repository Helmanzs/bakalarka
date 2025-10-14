#!/usr/bin/env bash

HOSTS_FILE="vars/hosts"

# Read all non-empty lines after the header (first line)
mapfile -t DATABASES < <(tail -n +2 "$HOSTS_FILE" | sed '/^\s*$/d')

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "Creating results directory at $RESULTS_DIR"
  mkdir -p "$RESULTS_DIR"
fi

for db in "${DATABASES[@]}"; do
  PLAYBOOK_PATH="$SCRIPT_DIR/setup/$db.yml"

  if [[ ! -f "$PLAYBOOK_PATH" ]]; then
    echo "Skipping: Playbook does not exist at $PLAYBOOK_PATH"
    continue
  fi

  echo
  echo "========================================="
  echo "Running playbook:"
  echo "  Database: $db"
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

  ansible-playbook "$PLAYBOOK_PATH" -e "is_master_run=true database=$db test_type='insert' results_dir=$RESULTS_DIR"
done
