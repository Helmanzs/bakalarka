#!/usr/bin/env bash
# import_iotdb.sh
# Usage: ./import_iotdb.sh data.csv

set -euo pipefail
IFS=$'\n\t'

if (( $# != 1 )); then
  echo "Usage: $0 <csv_file>" >&2
  exit 1
fi

CSV_FILE="$1"
CLI_CMD="/iotdb/sbin/start-cli.sh"
HOST="127.0.0.1"
PORT="6667"
USER="root"
PASS="root"
PREFIX="root.car_telemetry"

# sanity check
if [[ ! -r "$CSV_FILE" ]]; then
  echo "ERROR: Cannot read $CSV_FILE" >&2
  exit 1
fi
if [[ ! -x "$CLI_CMD" ]]; then
  echo "ERROR: $CLI_CMD not found or not executable" >&2
  exit 1
fi

# read header
read -r HEADER_LINE < "$CSV_FILE"
IFS=',' read -r -a COLS <<< "$HEADER_LINE"

TOTAL=$(( $(wc -l < "$CSV_FILE") - 1 ))
(( TOTAL > 0 )) || { echo "No data rows in $CSV_FILE" >&2; exit 1; }

echo "Importing $TOTAL rows into IoTDB at $HOST:$PORT/$PREFIX"
echo "Press Ctrl-C to abort…"

COUNT=0
first=true

while IFS= read -r LINE || [[ -n $LINE ]]; do
  # skip the header line
  if $first; then
    first=false
    continue
  fi

  ((COUNT++))
  printf "\r[%5d/%5d]" "$COUNT" "$TOTAL"

  # split fields
  IFS=',' read -r -a FIELDS <<< "$LINE"
  VALS=()
  for V in "${FIELDS[@]}"; do
    if [[ $V =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      VALS+=( "$V" )
    else
      ESC=${V//\'/\'\\\'\'}
      VALS+=( "'${ESC}'" )
    fi
  done
  IFS=, VAL_LIST="${VALS[*]}" ; unset IFS

  SQL="INSERT INTO ${PREFIX}(${HEADER_LINE}) VALUES(${VAL_LIST});"
  # for debugging, echo the SQL (comment out in production)
  echo -e "\n>> $SQL"

  # execute
  OUT=$("$CLI_CMD" -h "$HOST" -p "$PORT" -u "$USER" -pw "$PASS" -e "$SQL" 2>&1) || {
    echo -e "\n❗ Exit code $? on row #$COUNT:"
    echo "$OUT"
    exit 1
  }

  if grep -q "^ERROR" <<< "$OUT"; then
    echo -e "\n❗ Error on row #$COUNT (in-band):"
    echo "$OUT"
    exit 1
  fi

done < "$CSV_FILE"

echo -e "\n✅ Imported $TOTAL rows successfully."
